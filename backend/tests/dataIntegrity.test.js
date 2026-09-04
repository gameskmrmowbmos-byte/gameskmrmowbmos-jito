const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  calculateDates,
} = require('../src/services/recharge.service');
const {
  getAccessStatus,
} = require('../src/services/subscription.service');

test('expired subscription status does not mutate user identity fields', () => {
  const user = {
    _id: 'stable-user-id',
    role: 'operator',
    isActive: true,
    accountStatus: 'ACTIVE',
    approvalStatus: 'APPROVED',
    subscriptionType: 'PAID',
    subscriptionStatus: 'ACTIVE',
    subscriptionStartDate: new Date('2026-01-01T00:00:00.000Z'),
    subscriptionExpiryDate: new Date('2026-01-02T00:00:00.000Z'),
    rechargeStartDate: new Date('2026-01-01T00:00:00.000Z'),
    rechargeEndDate: new Date('2026-01-02T00:00:00.000Z'),
  };

  const before = JSON.stringify(user);
  const status = getAccessStatus(user, new Date('2026-01-03T00:00:00.000Z'));

  assert.equal(status.allowed, false);
  assert.equal(status.code, 'SUBSCRIPTION_EXPIRED');
  assert.equal(user._id, 'stable-user-id');
  assert.equal(JSON.stringify(user), before);
});

test('recharge date calculation does not change user identity or ownership', () => {
  const user = {
    _id: 'stable-user-id',
    role: 'operator',
    subscriptionStatus: 'ACTIVE',
    subscriptionExpiryDate: new Date('2099-09-01T00:00:00.000Z'),
  };

  const before = JSON.stringify(user);
  const dates = calculateDates(user, {
    validityDays: 10,
    startMode: 'FROM_CURRENT_EXPIRY',
  });

  assert.equal(dates.startDate.toISOString(), '2099-09-01T00:00:00.000Z');
  assert.equal(dates.expiryDate.toISOString(), '2099-09-11T00:00:00.000Z');
  assert.equal(JSON.stringify(user), before);
});

test('subscription and recharge services do not contain destructive history operations', () => {
  const files = [
    '../src/services/recharge.service.js',
    '../src/services/subscription.service.js',
    '../src/middleware/subscription.middleware.js',
  ];
  const destructivePattern =
    /\b(deleteMany|deleteOne|findByIdAndDelete|findOneAndDelete|replaceOne|findOneAndReplace|dropDatabase|drop)\b/;

  for (const file of files) {
    const source = fs.readFileSync(path.join(__dirname, file), 'utf8');
    assert.equal(
      destructivePattern.test(source),
      false,
      `${file} must not delete or replace historical data`,
    );
  }
});
