const mongoose = require('mongoose');
const User = require('../models/User');
const RechargePlan = require('../models/RechargePlan');
const RechargeHistory = require('../models/RechargeHistory');
const ApiError = require('../utils/apiError');
const { recordAudit } = require('./audit.service');

function addDays(date, days) {
  const value = new Date(date);
  value.setDate(value.getDate() + Number(days));
  return value;
}

function startOfToday() {
  return new Date();
}

function calculateDates(user, { validityDays, customExpiryDate, startMode }) {
  const now = new Date();
  const activeExpiry =
    user.subscriptionStatus === 'ACTIVE' &&
    user.subscriptionExpiryDate &&
    new Date(user.subscriptionExpiryDate) > now
      ? new Date(user.subscriptionExpiryDate)
      : null;

  const startDate =
    startMode === 'FROM_CURRENT_EXPIRY' && activeExpiry
      ? activeExpiry
      : startOfToday();

  const expiryDate = customExpiryDate
    ? new Date(customExpiryDate)
    : addDays(startDate, validityDays);

  if (!(expiryDate instanceof Date) || Number.isNaN(expiryDate.getTime())) {
    throw ApiError.badRequest('A valid expiry date is required');
  }
  if (expiryDate <= now) {
    throw ApiError.badRequest('Expiry date must be in the future');
  }

  return { startDate, expiryDate };
}

async function activateRecharge({ req, userId, admin, payload }) {
  // Data-integrity rule: recharge/expiry may only change access state and
  // recharge history. Never delete, replace, or detach Receipt, ReceiptItem,
  // PrintLog, or other historical user records from this service.
  const user = await User.findById(userId).select('+refreshTokenHash');
  if (!user || user.role === 'admin') throw ApiError.notFound('Customer not found');

  let plan = null;
  if (payload.planId) {
    plan = await RechargePlan.findById(payload.planId);
    if (!plan || !plan.isActive) throw ApiError.badRequest('Recharge plan is inactive or missing');
  }

  const validityDays = Number(payload.validityDays || plan?.validityDays);
  if (!payload.customExpiryDate && (!validityDays || validityDays < 1)) {
    throw ApiError.badRequest('Validity days or custom expiry date is required');
  }

  const { startDate, expiryDate } = calculateDates(user, {
    validityDays,
    customExpiryDate: payload.customExpiryDate,
    startMode: payload.startMode || 'FROM_TODAY',
  });

  const amount = Number(payload.amount ?? plan?.price ?? 0);
  if (Number.isNaN(amount) || amount < 0) {
    throw ApiError.badRequest('Amount must be zero or greater');
  }

  const session = await mongoose.startSession();
  let recharge;
  try {
    await session.withTransaction(async () => {
      recharge = await RechargeHistory.create(
        [
          {
            user: user._id,
            plan: plan?._id,
            planName: plan?.name || payload.planName || 'Custom Recharge',
            validityDays: payload.customExpiryDate ? undefined : validityDays,
            amount,
            startDate,
            expiryDate,
            rechargeType: plan ? 'PLAN' : 'CUSTOM',
            startMode: payload.startMode || 'FROM_TODAY',
            paymentMode: payload.paymentMode || 'Cash',
            paymentReference: payload.paymentReference,
            note: payload.note,
            createdByAdmin: admin._id,
          },
        ],
        { session },
      ).then((items) => items[0]);

      user.approvalStatus = 'APPROVED';
      user.accountStatus = 'ACTIVE';
      user.isActive = true;
      user.subscriptionStatus = 'ACTIVE';
      user.subscriptionType = 'PAID';
      user.subscriptionStartDate = startDate;
      user.subscriptionExpiryDate = expiryDate;
      user.rechargeStartDate = startDate;
      user.rechargeEndDate = expiryDate;
      user.currentPlanId = plan?._id;
      await user.save({ session });
    });
  } finally {
    await session.endSession();
  }

  await recordAudit({
    req,
    user: admin,
    action: 'recharge_activated',
    module: 'subscriptions',
    recordId: user._id,
    newValue: {
      rechargeId: recharge._id,
      expiryDate,
      amount,
      startMode: payload.startMode || 'FROM_TODAY',
    },
  });

  return { user, recharge };
}

module.exports = {
  activateRecharge,
  calculateDates,
};
