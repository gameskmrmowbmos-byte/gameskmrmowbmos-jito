const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const env = require('../config/env');
const OtpVerification = require('../models/OtpVerification');
const Settings = require('../models/Settings');
const User = require('../models/User');
const ApiError = require('../utils/apiError');

const OTP_ATTEMPT_LIMIT = 5;
const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const OTP_WINDOW_MS = 15 * 60 * 1000;
const OTP_WINDOW_LIMIT = 5;

function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

function normalizePhone(phoneNumber) {
  return phoneNumber.replace(/\D/g, '');
}

function otpHash(otp, email, purpose) {
  return crypto
    .createHmac('sha256', env.refreshSecret)
    .update(`${purpose}:${normalizeEmail(email)}:${otp}`)
    .digest('hex');
}

function generateOtp() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

async function uniqueUsernameFromEmail(email) {
  const base =
    email
      .split('@')[0]
      .replace(/[^a-z0-9_.-]/gi, '')
      .toLowerCase()
      .slice(0, 30) || 'user';
  let username = base.length >= 3 ? base : `${base}user`;
  let suffix = 1;
  while (await User.exists({ username })) {
    const tail = String(suffix++);
    username = `${base.slice(0, Math.max(3, 38 - tail.length))}${tail}`;
  }
  return username;
}

async function assertOtpRequestAllowed({ email, purpose, ipAddress }) {
  const now = new Date();
  const since = new Date(now.getTime() - OTP_WINDOW_MS);
  const recentQuery = {
    purpose,
    createdAt: { $gte: since },
    $or: [{ email }, { ipAddress }],
  };
  const recentCount = await OtpVerification.countDocuments(recentQuery);
  if (recentCount >= OTP_WINDOW_LIMIT) {
    throw ApiError.badRequest(
      'Too many OTP requests. Please try again later.',
      [],
      'OTP_RATE_LIMITED',
    );
  }

  const latest = await OtpVerification.findOne({ email, purpose })
    .sort({ createdAt: -1 })
    .select('createdAt');
  if (latest && now.getTime() - latest.createdAt.getTime() < OTP_RESEND_COOLDOWN_MS) {
    throw ApiError.badRequest(
      'Please wait before requesting another OTP.',
      [],
      'OTP_RATE_LIMITED',
    );
  }
}

async function createOtp({
  email,
  purpose,
  ipAddress,
  userAgent,
  phoneNumber,
  fullName,
  password,
}) {
  const normalizedEmail = normalizeEmail(email);
  await assertOtpRequestAllowed({ email: normalizedEmail, purpose, ipAddress });

  const otp = generateOtp();
  const payload = {
    email: normalizedEmail,
    purpose,
    otpHash: otpHash(otp, normalizedEmail, purpose),
    expiresAt: addMinutes(new Date(), env.otpExpiryMinutes),
    ipAddress,
    userAgent,
  };

  if (phoneNumber) payload.phoneNumber = normalizePhone(phoneNumber);
  if (fullName) payload.fullName = fullName.trim();
  if (password) payload.passwordHash = await bcrypt.hash(password, 12);

  await OtpVerification.create(payload);

  return {
    expiresInMinutes: env.otpExpiryMinutes,
    ...(env.showDevOtp ? { developmentOtp: otp } : {}),
  };
}

async function findOtpOrThrow({ email, purpose, otp, allowVerified = false }) {
  const normalizedEmail = normalizeEmail(email);
  const record = await OtpVerification.findOne({
    email: normalizedEmail,
    purpose,
    used: false,
  })
    .sort({ createdAt: -1 })
    .select('+otpHash +passwordHash');

  if (!record) {
    throw ApiError.badRequest('Invalid OTP.', [], 'OTP_INVALID');
  }
  if (record.verified && !allowVerified) {
    throw ApiError.badRequest('OTP has already been used.', [], 'OTP_ALREADY_USED');
  }
  if (record.expiresAt <= new Date()) {
    record.used = true;
    await record.save();
    throw ApiError.badRequest('OTP has expired.', [], 'OTP_EXPIRED');
  }
  if (record.attempts >= OTP_ATTEMPT_LIMIT) {
    record.used = true;
    await record.save();
    throw ApiError.badRequest(
      'Maximum OTP attempts exceeded.',
      [],
      'OTP_ATTEMPTS_EXCEEDED',
    );
  }

  const expected = otpHash(otp, normalizedEmail, purpose);
  const matches =
    expected.length === record.otpHash.length &&
    crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(record.otpHash));
  if (!matches) {
    record.attempts += 1;
    if (record.attempts >= OTP_ATTEMPT_LIMIT) record.used = true;
    await record.save();
    throw ApiError.badRequest('Invalid OTP.', [], 'OTP_INVALID');
  }

  return record;
}

async function sendRegistrationOtp({ fullName, email, phoneNumber, password, req }) {
  const normalizedEmail = normalizeEmail(email);
  const normalizedPhone = normalizePhone(phoneNumber);
  if (await User.exists({ email: normalizedEmail })) {
    throw ApiError.badRequest('Email is already registered.', [], 'EMAIL_ALREADY_REGISTERED');
  }
  if (await User.exists({ phoneNumber: normalizedPhone })) {
    throw ApiError.badRequest('Mobile number is already registered.', [], 'MOBILE_ALREADY_REGISTERED');
  }

  return createOtp({
    email: normalizedEmail,
    purpose: 'REGISTRATION',
    phoneNumber: normalizedPhone,
    fullName,
    password,
    ipAddress: req.ip,
    userAgent: req.get('user-agent'),
  });
}

async function verifyRegistrationOtp({ email, otp }) {
  const record = await findOtpOrThrow({ email, purpose: 'REGISTRATION', otp });
  const settings = await Settings.getApplicationSettings();
  const approvalStatus =
    settings.requireManualApproval === false
      ? settings.defaultApprovalStatus || 'APPROVED'
      : 'PENDING';
  const approvedNow = approvalStatus === 'APPROVED';
  const now = new Date();
  const trialEnd = approvedNow ? addDays(now, env.freeTrialDays) : null;

  if (await User.exists({ email: record.email })) {
    throw ApiError.badRequest('Email is already registered.', [], 'EMAIL_ALREADY_REGISTERED');
  }
  if (await User.exists({ phoneNumber: record.phoneNumber })) {
    throw ApiError.badRequest('Mobile number is already registered.', [], 'MOBILE_ALREADY_REGISTERED');
  }

  const user = await User.create({
    fullName: record.fullName,
    username: await uniqueUsernameFromEmail(record.email),
    email: record.email,
    phoneNumber: record.phoneNumber,
    passwordHash: record.passwordHash,
    role: 'operator',
    emailVerified: true,
    approvalStatus,
    approvedAt: approvedNow ? now : undefined,
    accountStatus: 'ACTIVE',
    isActive: true,
    subscriptionType: approvedNow ? 'TRIAL' : 'NONE',
    subscriptionStatus: approvedNow ? 'ACTIVE' : 'NOT_ACTIVE',
    subscriptionStartDate: approvedNow ? now : undefined,
    subscriptionExpiryDate: approvedNow ? trialEnd : undefined,
    trialStartDate: approvedNow ? now : undefined,
    trialEndDate: approvedNow ? trialEnd : undefined,
  });

  record.verified = true;
  record.used = true;
  await record.save();
  return user;
}

async function sendPasswordResetOtp({ email, req }) {
  const normalizedEmail = normalizeEmail(email);
  const user = await User.findOne({ email: normalizedEmail });
  if (!user || !user.isActive || user.emailVerified === false) {
    return { expiresInMinutes: env.otpExpiryMinutes };
  }

  return createOtp({
    email: normalizedEmail,
    purpose: 'PASSWORD_RESET',
    ipAddress: req.ip,
    userAgent: req.get('user-agent'),
  });
}

async function verifyPasswordResetOtp({ email, otp }) {
  const record = await findOtpOrThrow({
    email,
    purpose: 'PASSWORD_RESET',
    otp,
    allowVerified: true,
  });
  record.verified = true;
  await record.save();
}

async function resetPasswordWithOtp({ email, otp, password }) {
  const record = await findOtpOrThrow({ email, purpose: 'PASSWORD_RESET', otp });
  const user = await User.findOne({ email: record.email }).select('+passwordHash +refreshTokenHash');
  if (!user || !user.isActive || user.emailVerified === false) {
    throw ApiError.badRequest('Invalid OTP.', [], 'OTP_INVALID');
  }
  await user.setPassword(password);
  user.refreshTokenHash = undefined;
  user.passwordResetTokenHash = undefined;
  user.passwordResetExpires = undefined;
  await user.save();

  record.verified = true;
  record.used = true;
  await record.save();
  return user;
}

module.exports = {
  normalizeEmail,
  normalizePhone,
  sendRegistrationOtp,
  verifyRegistrationOtp,
  sendPasswordResetOtp,
  verifyPasswordResetOtp,
  resetPasswordWithOtp,
};
