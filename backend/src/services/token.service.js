const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const ApiError = require('../utils/apiError');

function deviceHash(deviceId) {
  if (!deviceId) return null;
  return crypto.createHash('sha256').update(`${deviceId}`).digest('hex');
}

function signAccessToken(user, deviceId) {
  return jwt.sign(
    {
      sub: user._id.toString(),
      role: user.role,
      type: 'access',
      tokenVersion: user.tokenVersion || 0,
      deviceIdHash: deviceHash(deviceId),
    },
    env.accessSecret,
    { expiresIn: env.accessExpiresIn, issuer: 'matka-management-api' },
  );
}

function signRefreshToken(user, deviceId) {
  return jwt.sign(
    {
      sub: user._id.toString(),
      type: 'refresh',
      tokenId: crypto.randomUUID(),
      tokenVersion: user.tokenVersion || 0,
      deviceIdHash: deviceHash(deviceId),
    },
    env.refreshSecret,
    { expiresIn: env.refreshExpiresIn, issuer: 'matka-management-api' },
  );
}

function verifyToken(token, type) {
  try {
    const secret = type === 'refresh' ? env.refreshSecret : env.accessSecret;
    const payload = jwt.verify(token, secret, {
      issuer: 'matka-management-api',
    });
    if (payload.type !== type) throw new Error('Incorrect token type');
    return payload;
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw ApiError.unauthorized(`${type} token has expired`);
    }
    throw ApiError.unauthorized(`Invalid ${type} token`);
  }
}

function createTokenPair(user, deviceId) {
  return {
    accessToken: signAccessToken(user, deviceId),
    refreshToken: signRefreshToken(user, deviceId),
  };
}

module.exports = {
  createTokenPair,
  signAccessToken,
  signRefreshToken,
  verifyAccessToken: (token) => verifyToken(token, 'access'),
  verifyRefreshToken: (token) => verifyToken(token, 'refresh'),
};
