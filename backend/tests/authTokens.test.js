const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const tokenService = require('../src/services/token.service');

test('auth tokens store the device hash instead of the raw device id', () => {
  const deviceId = 'device-0123456789abcdef';
  const expectedHash = crypto.createHash('sha256').update(deviceId).digest('hex');
  const user = {
    _id: { toString: () => '507f1f77bcf86cd799439011' },
    role: 'operator',
    tokenVersion: 3,
  };

  const tokens = tokenService.createTokenPair(user, deviceId);
  const accessPayload = tokenService.verifyAccessToken(tokens.accessToken);
  const refreshPayload = tokenService.verifyRefreshToken(tokens.refreshToken);

  assert.equal(accessPayload.deviceIdHash, expectedHash);
  assert.equal(refreshPayload.deviceIdHash, expectedHash);
  assert.equal(accessPayload.deviceId, undefined);
  assert.equal(refreshPayload.deviceId, undefined);
});
