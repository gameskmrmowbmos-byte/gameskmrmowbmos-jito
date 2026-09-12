const User = require('../models/User');
const tokenService = require('../services/token.service');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');

const MIN_DEVICE_ID_LENGTH = 16;
const DEVICE_BOUND_MESSAGE =
  'This account is already logged in on another device. Please logout from that device first.';
const LAST_SEEN_UPDATE_INTERVAL_MS = 60 * 1000;

function requestDeviceId(req) {
  return `${req.get('x-device-id') || req.body?.deviceId || ''}`.trim();
}

const authenticate = asyncHandler(async (req, _res, next) => {
  const authorization = req.get('authorization') || '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    throw ApiError.unauthorized('A valid Bearer access token is required');
  }

  const payload = tokenService.verifyAccessToken(token);
  const user = await User.findById(payload.sub).select(
    '+tokenVersion +activeDeviceIdHash',
  );
  if (!user) throw ApiError.unauthorized('Token user no longer exists');
  if (!user.isActive) throw ApiError.forbidden('This account is inactive');
  if (user.role !== 'admin' && user.accountStatus === 'DISABLED') {
    throw ApiError.forbidden('This account is disabled', 'ACCOUNT_DISABLED');
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
  if ((user.tokenVersion || 0) !== (payload.tokenVersion || 0)) {
    throw ApiError.unauthorized(
      'Your login session has been reset by the administrator. Please login again.',
      'SESSION_REVOKED',
    );
  }
  const deviceId = requestDeviceId(req);
  if (deviceId.length < MIN_DEVICE_ID_LENGTH || !user.activeDeviceIdHash) {
    throw ApiError.unauthorized(
      'Device session is no longer valid. Please login again.',
      'DEVICE_SESSION_REQUIRED',
    );
  }
  if (payload.deviceIdHash && user.deviceHash(deviceId) !== payload.deviceIdHash) {
    throw ApiError.unauthorized(
      'Device session is no longer valid. Please login again.',
      'SESSION_REVOKED',
    );
  }
  if (!user.matchesDevice(deviceId)) {
    throw ApiError.forbidden(DEVICE_BOUND_MESSAGE, 'DEVICE_ALREADY_BOUND');
  }

  const lastSeenAt = user.activeDeviceLastSeenAt?.getTime?.() || 0;
  if (Date.now() - lastSeenAt > LAST_SEEN_UPDATE_INTERVAL_MS) {
    User.updateOne(
      { _id: user._id },
      { $set: { activeDeviceLastSeenAt: new Date() } },
    ).catch(() => undefined);
  }

  req.user = user;
  next();
});

module.exports = authenticate;
