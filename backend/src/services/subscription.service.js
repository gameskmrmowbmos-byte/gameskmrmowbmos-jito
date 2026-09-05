const ApiError = require('../utils/apiError');

function daysRemaining(expiryDate, now = new Date()) {
  if (!expiryDate) return 0;
  return Math.max(
    0,
    Math.ceil((new Date(expiryDate).getTime() - now.getTime()) / 86400000),
  );
}

function subscriptionDates(user) {
  const type = user.subscriptionType || 'NONE';
  if (type === 'TRIAL') {
    return {
      type,
      startDate: user.trialStartDate || user.subscriptionStartDate || null,
      expiryDate: user.trialEndDate || user.subscriptionExpiryDate || null,
    };
  }
  if (type === 'PAID') {
    return {
      type,
      startDate: user.rechargeStartDate || user.subscriptionStartDate || null,
      expiryDate: user.rechargeEndDate || user.subscriptionExpiryDate || null,
    };
  }
  return {
    type,
    startDate: user.subscriptionStartDate || null,
    expiryDate: user.subscriptionExpiryDate || null,
  };
}

function getAccessStatus(user, now = new Date()) {
  if (user.role === 'admin') {
    return {
      allowed: true,
      code: null,
      message: 'Admin access active',
      accountStatus: user.accountStatus || 'ACTIVE',
      approvalStatus: user.approvalStatus || 'APPROVED',
      entryAccessBlocked: false,
      subscriptionType: user.subscriptionType || 'PAID',
      subscriptionStatus: 'ACTIVE',
      startDate: user.subscriptionStartDate || null,
      expiryDate: user.subscriptionExpiryDate || null,
      daysRemaining: daysRemaining(user.subscriptionExpiryDate, now),
      subscription: {
        type: user.subscriptionType || 'PAID',
        status: 'ACTIVE',
        hasAccess: true,
        startDate: user.subscriptionStartDate || null,
        endDate: user.subscriptionExpiryDate || null,
        daysRemaining: daysRemaining(user.subscriptionExpiryDate, now),
      },
    };
  }

  const approvalStatus = user.approvalStatus || 'APPROVED';
  const accountStatus = user.accountStatus || (user.isActive ? 'ACTIVE' : 'DISABLED');
  const entryAccessBlocked =
    user.entryAccessBlocked === true || accountStatus === 'BLOCKED';
  const dates = subscriptionDates(user);
  const expiryDate = dates.expiryDate || null;
  const expiryPassed = expiryDate ? new Date(expiryDate) <= now : false;
  const storedSubscriptionStatus = user.subscriptionStatus || 'NOT_ACTIVE';
  const subscriptionStatus =
    storedSubscriptionStatus === 'ACTIVE' && !expiryPassed
      ? 'ACTIVE'
      : expiryDate && expiryPassed
        ? 'EXPIRED'
        : storedSubscriptionStatus;

  let code = null;
  let message = 'Access active';

  if (!user.isActive || accountStatus === 'DISABLED') {
    code = 'ACCOUNT_DISABLED';
    message = 'Account is disabled';
  } else if (approvalStatus === 'PENDING') {
    code = 'ACCOUNT_PENDING_APPROVAL';
    message = 'Account is pending approval';
  } else if (approvalStatus === 'REJECTED') {
    code = 'ACCOUNT_REJECTED';
    message = 'Account was not approved';
  } else if (entryAccessBlocked) {
    code = 'ENTRY_ACCESS_BLOCKED';
    message =
      'Your entry access has been blocked by the administrator. Please contact the administrator.';
  } else if (subscriptionStatus === 'EXPIRED') {
    code = 'SUBSCRIPTION_EXPIRED';
    message =
      'Your subscription has expired. Please contact the administrator to recharge your account.';
  } else if (subscriptionStatus !== 'ACTIVE') {
    code = 'SUBSCRIPTION_NOT_ACTIVE';
    message =
      'Your subscription is not active. Please contact the administrator to recharge your account.';
  }

  return {
    allowed: code == null,
    code,
    message,
    accountStatus,
    approvalStatus,
    entryAccessBlocked,
    subscriptionType: dates.type,
    subscriptionStatus,
    startDate: dates.startDate,
    expiryDate,
    daysRemaining: daysRemaining(expiryDate, now),
    subscription: {
      type: dates.type,
      status: subscriptionStatus,
      hasAccess: code == null,
      startDate: dates.startDate,
      endDate: expiryDate,
      daysRemaining: daysRemaining(expiryDate, now),
    },
  };
}

function assertFlutterAccess(user) {
  if (user.role === 'admin') return getAccessStatus(user);
  const status = getAccessStatus(user);
  if (!status.allowed) {
    throw ApiError.forbidden(status.message, status.code);
  }
  return status;
}

module.exports = {
  getAccessStatus,
  assertFlutterAccess,
  daysRemaining,
};
