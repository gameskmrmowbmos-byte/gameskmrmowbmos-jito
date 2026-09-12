const crypto = require('crypto');
const User = require('../models/User');
const ApiError = require('../utils/apiError');
const tokenService = require('./token.service');

const MAX_FAILED_ATTEMPTS = 5;
const LOCK_DURATION_MS = 15 * 60 * 1000;
const MIN_DEVICE_ID_LENGTH = 16;
const DEVICE_BOUND_MESSAGE =
  'This account is already logged in on another device. Please logout from that device first.';
const USERNAME_PATTERN = /^[a-z0-9_.-]{3,40}$/;
const VALID_ROLES = new Set(['admin', 'operator']);

function normalizedDeviceId(deviceId) {
  return `${deviceId || ''}`.trim();
}

function clearDeviceBinding(user) {
  user.activeDeviceIdHash = undefined;
  user.activeDeviceIdMasked = undefined;
  user.activeDeviceBoundAt = undefined;
  user.activeDeviceLastSeenAt = undefined;
}

function enforceSingleDevice(user, deviceId, { unauthorizedOnMissing = false } = {}) {
  const normalized = normalizedDeviceId(deviceId);
  if (normalized.length < MIN_DEVICE_ID_LENGTH) {
    if (unauthorizedOnMissing) {
      throw ApiError.unauthorized(
        'Device session is missing. Please login again.',
        'DEVICE_ID_REQUIRED',
      );
    }
    throw ApiError.badRequest(
      'A valid device identifier is required.',
      [],
      'DEVICE_ID_REQUIRED',
    );
  }

  if (!user.activeDeviceIdHash) {
    user.bindDevice(normalized);
  } else if (!user.matchesDevice(normalized)) {
    throw ApiError.forbidden(DEVICE_BOUND_MESSAGE, 'DEVICE_ALREADY_BOUND');
  } else {
    user.activeDeviceLastSeenAt = new Date();
  }

  return normalized;
}

function usernameBaseFrom(user) {
  const suffix = user._id.toString().slice(-6);
  const source =
    user.username ||
    user.email?.split('@')[0] ||
    user.fullName ||
    `user-${suffix}`;
  const normalized = source
    .toString()
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_.-]+/g, '.')
    .replace(/^[_.-]+|[_.-]+$/g, '')
    .slice(0, 32);
  if (normalized.length >= 3) return normalized;
  return `${normalized || 'user'}-${suffix}`.slice(0, 40);
}

async function repairRequiredIdentityFields(user) {
  if (!VALID_ROLES.has(user.role)) {
    user.role = 'operator';
  }

  if (!user.fullName || !user.fullName.trim()) {
    user.fullName =
      user.email?.split('@')[0] ||
      user.username ||
      `User ${user._id.toString().slice(-6)}`;
  }
  if (user.fullName.trim().length < 2) {
    user.fullName = `User ${user._id.toString().slice(-6)}`;
  }

  if (USERNAME_PATTERN.test(user.username || '')) return;

  const base = usernameBaseFrom(user);
  let username = base;
  const exists = await User.exists({
    _id: { $ne: user._id },
    username,
  });
  if (exists) username = `${base.slice(0, 32)}-${user._id.toString().slice(-6)}`;
  user.username = username.slice(0, 40);
}

async function authenticate(identifier, password, { deviceId } = {}) {
  const normalized = identifier.trim().toLowerCase();
  const user = await User.findOne({
    $or: [{ email: normalized }, { username: normalized }],
  }).select(
    '+passwordHash +refreshTokenHash +failedLoginAttempts +lockUntil +loginHistory +tokenVersion +activeDeviceIdHash',
  );

  if (!user) throw ApiError.unauthorized('Invalid email or password.', 'INVALID_CREDENTIALS');
  await repairRequiredIdentityFields(user);
  if (user.role === 'admin' && (!user.isActive || user.accountStatus === 'BLOCKED')) {
    throw ApiError.forbidden('This admin account is inactive', 'ACCOUNT_BLOCKED');
  }
  if (!user.isActive) throw ApiError.forbidden('This account is inactive', 'ACCOUNT_DISABLED');
  if (user.role !== 'admin' && user.accountStatus === 'DISABLED') {
    throw ApiError.forbidden('This account is disabled', 'ACCOUNT_DISABLED');
  }
  if (user.role !== 'admin' && user.emailVerified === false) {
    const approvalStatus = user.approvalStatus || 'APPROVED';
    if (
      approvalStatus === 'APPROVED' &&
      user.isActive &&
      user.accountStatus !== 'DISABLED' &&
      user.accountStatus !== 'BLOCKED'
    ) {
      user.emailVerified = true;
    } else {
      throw ApiError.forbidden('Email is not verified', 'EMAIL_NOT_VERIFIED');
    }
  }

  if (user.lockUntil && user.lockUntil > new Date()) {
    throw new ApiError(
      429,
      'Account temporarily locked after repeated failed login attempts',
    );
  }

  const valid = await user.verifyPassword(password);
  if (!valid) {
    user.failedLoginAttempts += 1;
    if (user.failedLoginAttempts >= MAX_FAILED_ATTEMPTS) {
      user.lockUntil = new Date(Date.now() + LOCK_DURATION_MS);
      user.failedLoginAttempts = 0;
    }
    await user.save();
    throw ApiError.unauthorized('Invalid email or password.', 'INVALID_CREDENTIALS');
  }

  if (user.role !== 'admin' && (user.approvalStatus || 'APPROVED') === 'PENDING') {
    throw ApiError.forbidden(
      'Your account is awaiting administrator approval.',
      'ACCOUNT_PENDING_APPROVAL',
    );
  }
  if (user.role !== 'admin' && user.approvalStatus === 'REJECTED') {
    throw ApiError.forbidden('Your account was not approved.', 'ACCOUNT_REJECTED');
  }

  const sessionDeviceId = enforceSingleDevice(user, deviceId);

  user.failedLoginAttempts = 0;
  user.lockUntil = undefined;
  user.lastLogin = new Date();
  const tokens = tokenService.createTokenPair(user, sessionDeviceId);
  user.setRefreshToken(tokens.refreshToken);
  await user.save();
  return { user, tokens };
}

async function rotateRefreshToken(rawToken, { deviceId } = {}) {
  const payload = tokenService.verifyRefreshToken(rawToken);
  const user = await User.findById(payload.sub).select(
    '+refreshTokenHash +tokenVersion +activeDeviceIdHash',
  );

  if (
    !user ||
    !user.isActive ||
    user.accountStatus === 'DISABLED' ||
    (user.role !== 'admin' && (user.approvalStatus || 'APPROVED') === 'PENDING') ||
    (user.role !== 'admin' && user.approvalStatus === 'REJECTED') ||
    (user.tokenVersion || 0) !== (payload.tokenVersion || 0) ||
    !user.matchesRefreshToken(rawToken)
  ) {
    throw ApiError.unauthorized('Refresh session is no longer valid', 'SESSION_REVOKED');
  }

  const requestDeviceId = normalizedDeviceId(deviceId);
  const tokenDeviceId = normalizedDeviceId(payload.deviceId);
  const tokenDeviceHash = normalizedDeviceId(payload.deviceIdHash);
  const requestDeviceHash = requestDeviceId ? user.deviceHash(requestDeviceId) : '';
  if (
    tokenDeviceHash &&
    tokenDeviceHash !== requestDeviceHash
  ) {
    throw ApiError.unauthorized('Refresh session is no longer valid', 'SESSION_REVOKED');
  }
  if (tokenDeviceId && tokenDeviceId !== requestDeviceId) {
    throw ApiError.unauthorized('Refresh session is no longer valid', 'SESSION_REVOKED');
  }
  const sessionDeviceId = enforceSingleDevice(user, requestDeviceId || tokenDeviceId, {
    unauthorizedOnMissing: true,
  });

  const tokens = tokenService.createTokenPair(user, sessionDeviceId);
  user.setRefreshToken(tokens.refreshToken);
  await user.save();
  return { user, tokens };
}

async function invalidateRefreshToken(rawToken, { deviceId } = {}) {
  if (!rawToken) return;
  try {
    const payload = tokenService.verifyRefreshToken(rawToken);
    const user = await User.findById(payload.sub).select(
      '+refreshTokenHash +activeDeviceIdHash +tokenVersion',
    );
    if (user && user.matchesRefreshToken(rawToken)) {
      const requestDeviceId = normalizedDeviceId(deviceId);
      const tokenDeviceId = normalizedDeviceId(payload.deviceId);
      const tokenDeviceHash = normalizedDeviceId(payload.deviceIdHash);
      const logoutDeviceId = requestDeviceId || tokenDeviceId;
      const logoutDeviceMatches = logoutDeviceId
        ? user.matchesDevice(logoutDeviceId)
        : tokenDeviceHash && user.activeDeviceIdHash === tokenDeviceHash;
      user.refreshTokenHash = undefined;
      user.tokenVersion = (user.tokenVersion || 0) + 1;
      if (logoutDeviceMatches) {
        clearDeviceBinding(user);
      }
      await user.save();
    }
  } catch {
    // Logout remains idempotent even when a supplied token has expired.
  }
}

async function createResetToken(email) {
  const user = await User.findOne({ email: email.trim().toLowerCase() }).select(
    '+passwordResetTokenHash +passwordResetExpires',
  );
  if (!user || !user.isActive) return null;
  const rawToken = user.createPasswordResetToken();
  await user.save({ validateBeforeSave: false });
  return { user, rawToken };
}

async function resetPassword(rawToken, password) {
  const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
  const user = await User.findOne({
    passwordResetTokenHash: tokenHash,
    passwordResetExpires: { $gt: Date.now() },
  }).select(
    '+passwordHash +passwordResetTokenHash +passwordResetExpires +refreshTokenHash',
  );

  if (!user) throw ApiError.badRequest('Reset token is invalid or has expired');
  await user.setPassword(password);
  user.passwordResetTokenHash = undefined;
  user.passwordResetExpires = undefined;
  user.refreshTokenHash = undefined;
  await user.save();
  return user;
}

module.exports = {
  authenticate,
  rotateRefreshToken,
  invalidateRefreshToken,
  createResetToken,
  resetPassword,
};
