const User = require('../models/User');
const Market = require('../models/Market');
const RechargePlan = require('../models/RechargePlan');
const RechargeHistory = require('../models/RechargeHistory');
const AuditLog = require('../models/AuditLog');
const Settings = require('../models/Settings');
const env = require('../config/env');
const ApiError = require('../utils/apiError');
const logger = require('../utils/logger');
const asyncHandler = require('../utils/asyncHandler');
const { getPagination, paginationMeta } = require('../utils/pagination');
const { success } = require('../utils/response');
const { recordAudit } = require('../services/audit.service');
const { activateRecharge } = require('../services/recharge.service');
const { getAccessStatus } = require('../services/subscription.service');
const { standardPannaNumberSetPayload } = require('../services/gameConfig.service');
const { serializeMarketStatus } = require('../services/marketAvailability.service');
const {
  marketSort,
  nextMarketDisplayOrder,
  normalizeMarketDisplayOrder,
  reorderMarkets,
} = require('../services/marketOrder.service');

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function customerFilter(query = {}) {
  const filter = { role: { $ne: 'admin' }, isDeleted: { $ne: true } };
  if (query.search) {
    const escaped = escapeRegex(query.search.trim());
    filter.$or = [
      { fullName: { $regex: escaped, $options: 'i' } },
      { username: { $regex: escaped, $options: 'i' } },
      { email: { $regex: escaped, $options: 'i' } },
      { phoneNumber: { $regex: escaped, $options: 'i' } },
    ];
  }
  if (query.approvalStatus) filter.approvalStatus = query.approvalStatus;
  if (query.accountStatus) filter.accountStatus = query.accountStatus;
  if (query.subscriptionStatus) filter.subscriptionStatus = query.subscriptionStatus;
  if (query.status === 'active') filter.isActive = true;
  if (query.status === 'inactive') filter.isActive = false;
  return filter;
}

function serializeUser(user) {
  const safe = user.toSafeObject ? user.toSafeObject() : user;
  return {
    ...safe,
    accessStatus: getAccessStatus(user),
  };
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

const dashboard = asyncHandler(async (_req, res) => {
  const now = new Date();
  const soon = new Date();
  soon.setDate(soon.getDate() + 3);
  const customerBase = { role: { $ne: 'admin' }, isDeleted: { $ne: true } };

  const [
    activeRecharges,
    totalMarkets,
    customers,
    recentCustomers,
    recentRecharges,
  ] = await Promise.all([
    RechargeHistory.countDocuments({ status: 'ACTIVE', expiryDate: { $gt: now } }),
    Market.countDocuments(),
    User.find(customerBase),
    User.find(customerBase).sort({ createdAt: -1 }).limit(8),
    RechargeHistory.find()
      .populate('user', 'fullName username phoneNumber')
      .populate('createdByAdmin', 'fullName username')
      .sort({ createdAt: -1 })
      .limit(8),
  ]);

  const customerStatuses = customers.map((user) => ({
    user,
    accessStatus: getAccessStatus(user, now),
  }));
  const totalCustomers = customers.length;
  const activeCustomers = customerStatuses.filter(
    ({ user }) => user.isActive && (user.accountStatus || 'ACTIVE') === 'ACTIVE',
  ).length;
  const expiredCustomers = customerStatuses.filter(
    ({ accessStatus }) => accessStatus.subscriptionStatus === 'EXPIRED',
  ).length;
  const trialUsers = customerStatuses.filter(
    ({ accessStatus }) => accessStatus.subscriptionType === 'TRIAL',
  ).length;
  const activeSubscriptions = customerStatuses.filter(
    ({ accessStatus }) => accessStatus.allowed,
  ).length;
  const pendingApproval = customers.filter(
    (user) => (user.approvalStatus || 'APPROVED') === 'PENDING',
  ).length;
  const blockedCustomers = customers.filter((user) => user.entryAccessBlocked === true).length;
  const expiringSoonUsers = customerStatuses
    .filter(({ accessStatus }) => {
      if (!accessStatus.expiryDate || accessStatus.subscriptionStatus !== 'ACTIVE') return false;
      const expiry = new Date(accessStatus.expiryDate);
      return expiry > now && expiry <= soon;
    })
    .sort(
      (a, b) =>
        new Date(a.accessStatus.expiryDate).getTime() -
        new Date(b.accessStatus.expiryDate).getTime(),
    )
    .slice(0, 8)
    .map(({ user }) => user);
  const expiringSoon = expiringSoonUsers.length;
  if (!env.isProduction) {
    logger.info(
      `Admin dashboard request admin=${_req.user?._id || '-'} role=${_req.user?.role || '-'} totalCustomers=${totalCustomers}`,
    );
  }

  return success(res, {
    data: {
      summary: {
        totalCustomers,
        activeCustomers,
        expiredCustomers,
        trialUsers,
        activeSubscriptions,
        pendingApproval,
        blockedCustomers,
        activeRecharges,
        expiringSoon,
        totalMarkets,
      },
      recentCustomers: recentCustomers.map(serializeUser),
      recentRecharges,
      expiringSoonUsers: expiringSoonUsers.map(serializeUser),
    },
  });
});

const listUsers = asyncHandler(async (req, res) => {
  const { page, limit, skip } = getPagination(req.query, 25);
  const filter = customerFilter(req.query);
  const [users, total] = await Promise.all([
    User.find(filter)
      .populate('assignedMarkets', 'name code')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    User.countDocuments(filter),
  ]);
  if (!env.isProduction) {
    logger.info(
      `Admin users request admin=${req.user?._id || '-'} role=${req.user?.role || '-'} filter=${JSON.stringify(filter)} returned=${users.length} total=${total}`,
    );
  }
  return success(res, {
    data: { users: users.map(serializeUser) },
    pagination: paginationMeta(page, limit, total),
  });
});

const getUser = asyncHandler(async (req, res) => {
  const user = await User.findOne({ _id: req.params.id, role: { $ne: 'admin' }, isDeleted: { $ne: true } })
    .populate('assignedMarkets', 'name code')
    .select('+loginHistory');
  if (!user) throw ApiError.notFound('Customer not found');
  return success(res, { data: { user: serializeUser(user) } });
});

async function updateUserState(req, res, fields, action, message) {
  const user = await User.findOne({ _id: req.params.id, role: { $ne: 'admin' }, isDeleted: { $ne: true } }).select(
    '+refreshTokenHash',
  );
  if (!user) throw ApiError.notFound('Customer not found');
  const previousValue = user.toSafeObject();
  Object.assign(user, fields);
  if (
    fields.accountStatus === 'BLOCKED' ||
    fields.accountStatus === 'DISABLED' ||
    fields.approvalStatus === 'REJECTED' ||
    fields.isActive === false
  ) {
    user.refreshTokenHash = undefined;
  }
  await user.save();
  await recordAudit({
    req,
    user: req.user,
    action,
    module: 'admin_users',
    recordId: user._id,
    previousValue,
    newValue: user.toSafeObject(),
  });
  return success(res, { message, data: { user: serializeUser(user) } });
}

const approveUser = asyncHandler(async (req, res) => {
  const user = await User.findOne({ _id: req.params.id, role: { $ne: 'admin' }, isDeleted: { $ne: true } }).select(
    '+refreshTokenHash',
  );
  if (!user) throw ApiError.notFound('Customer not found');
  const previousValue = user.toSafeObject();
  const now = new Date();
  user.approvalStatus = 'APPROVED';
  user.accountStatus = 'ACTIVE';
  user.isActive = true;
  user.emailVerified = true;
  user.approvedAt = user.approvedAt || now;
  user.approvedBy = user.approvedBy || req.user._id;
  if (!user.trialStartDate && !user.trialEndDate && user.subscriptionType !== 'PAID') {
    const trialEnd = addDays(now, env.freeTrialDays);
    user.subscriptionType = 'TRIAL';
    user.subscriptionStatus = 'ACTIVE';
    user.subscriptionStartDate = now;
    user.subscriptionExpiryDate = trialEnd;
    user.trialStartDate = now;
    user.trialEndDate = trialEnd;
  }
  await user.save();
  logger.info(`Account approved user=${user._id} admin=${req.user._id}`);
  await recordAudit({
    req,
    user: req.user,
    action: 'user_approved',
    module: 'admin_users',
    recordId: user._id,
    previousValue,
    newValue: user.toSafeObject(),
  });
  return success(res, { message: 'User approved', data: { user: serializeUser(user) } });
});

const rejectUser = asyncHandler((req, res) =>
  updateUserState(
    req,
    res,
    { approvalStatus: 'REJECTED' },
    'user_rejected',
    'User rejected',
  ),
);

const blockUser = asyncHandler((req, res) =>
  updateUserState(
    req,
    res,
    {
      entryAccessBlocked: true,
      blockedAt: new Date(),
      blockedBy: req.user._id,
      blockReason: req.body.reason,
      accountStatus: 'ACTIVE',
      isActive: true,
    },
    'entry_access_blocked',
    'Entry access blocked',
  ),
);

const unblockUser = asyncHandler((req, res) =>
  updateUserState(
    req,
    res,
    {
      entryAccessBlocked: false,
      blockedAt: undefined,
      blockedBy: undefined,
      blockReason: undefined,
      accountStatus: 'ACTIVE',
      isActive: true,
    },
    'entry_access_unblocked',
    'Entry access unblocked',
  ),
);

const resetDeviceLogin = asyncHandler(async (req, res) => {
  const user = await User.findOne({ _id: req.params.id, role: { $ne: 'admin' }, isDeleted: { $ne: true } }).select(
    '+refreshTokenHash +activeDeviceIdHash +tokenVersion',
  );
  if (!user) throw ApiError.notFound('Customer not found');
  const previousValue = user.toSafeObject();
  user.activeDeviceIdHash = undefined;
  user.activeDeviceIdMasked = undefined;
  user.activeDeviceBoundAt = undefined;
  user.activeDeviceLastSeenAt = undefined;
  user.refreshTokenHash = undefined;
  user.tokenVersion = (user.tokenVersion || 0) + 1;
  user.deviceResetAt = new Date();
  user.deviceResetBy = req.user._id;
  await user.save();
  logger.info(`Device login reset user=${user._id} admin=${req.user._id}`);
  await recordAudit({
    req,
    user: req.user,
    action: 'device_login_reset',
    module: 'admin_users',
    recordId: user._id,
    previousValue,
    newValue: user.toSafeObject(),
  });
  return success(res, { message: 'Device login reset', data: { user: serializeUser(user) } });
});

const activateUser = asyncHandler((req, res) =>
  updateUserState(
    req,
    res,
    { accountStatus: 'ACTIVE', isActive: true },
    'user_activated',
    'User activated',
  ),
);

const disableUser = asyncHandler((req, res) =>
  updateUserState(
    req,
    res,
    { accountStatus: 'DISABLED', isActive: false },
    'user_disabled',
    'User disabled',
  ),
);

const rechargeUser = asyncHandler(async (req, res) => {
  const result = await activateRecharge({
    req,
    userId: req.params.id,
    admin: req.user,
    payload: req.body,
  });
  return success(res, {
    statusCode: 201,
    message: 'Recharge activated',
    data: {
      user: serializeUser(result.user),
      recharge: result.recharge,
    },
  });
});

const userRecharges = asyncHandler(async (req, res) => {
  const recharges = await RechargeHistory.find({ user: req.params.id })
    .populate('plan', 'name code validityDays price')
    .populate('createdByAdmin', 'fullName username')
    .sort({ createdAt: -1 });
  return success(res, { data: { recharges } });
});

const listRecharges = asyncHandler(async (req, res) => {
  const { page, limit, skip } = getPagination(req.query, 25);
  const filter = {};
  if (req.query.user) filter.user = req.query.user;
  if (req.query.status) filter.status = req.query.status;
  if (req.query.plan) filter.plan = req.query.plan;
  if (req.query.from || req.query.to) {
    filter.createdAt = {};
    if (req.query.from) filter.createdAt.$gte = new Date(`${req.query.from}T00:00:00.000Z`);
    if (req.query.to) filter.createdAt.$lte = new Date(`${req.query.to}T23:59:59.999Z`);
  }
  const [recharges, total] = await Promise.all([
    RechargeHistory.find(filter)
      .populate('user', 'fullName username email phoneNumber')
      .populate('plan', 'name code validityDays price')
      .populate('createdByAdmin', 'fullName username')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    RechargeHistory.countDocuments(filter),
  ]);
  return success(res, {
    data: { recharges },
    pagination: paginationMeta(page, limit, total),
  });
});

const listPlans = asyncHandler(async (req, res) => {
  const filter = {};
  if (req.query.status === 'active') filter.isActive = true;
  if (req.query.status === 'inactive') filter.isActive = false;
  const plans = await RechargePlan.find(filter).sort({ validityDays: 1, price: 1 });
  return success(res, { data: { plans } });
});

const createPlan = asyncHandler(async (req, res) => {
  const { name, code, validityDays, price, description, isActive } = req.body;
  const plan = await RechargePlan.create({
    name,
    code,
    validityDays,
    price,
    description,
    isActive,
    createdBy: req.user._id,
    updatedBy: req.user._id,
  });
  await recordAudit({
    req,
    user: req.user,
    action: 'recharge_plan_created',
    module: 'plans',
    recordId: plan._id,
    newValue: plan.toObject(),
  });
  return success(res, { statusCode: 201, message: 'Plan created', data: { plan } });
});

const updatePlan = asyncHandler(async (req, res) => {
  const plan = await RechargePlan.findById(req.params.id);
  if (!plan) throw ApiError.notFound('Plan not found');
  const previousValue = plan.toObject();
  for (const field of ['name', 'code', 'validityDays', 'price', 'description', 'isActive']) {
    if (req.body[field] !== undefined) plan[field] = req.body[field];
  }
  plan.updatedBy = req.user._id;
  await plan.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'recharge_plan_updated',
    module: 'plans',
    recordId: plan._id,
    previousValue,
    newValue: plan.toObject(),
  });
  return success(res, { message: 'Plan updated', data: { plan } });
});

const setPlanStatus = asyncHandler(async (req, res) => {
  const plan = await RechargePlan.findById(req.params.id);
  if (!plan) throw ApiError.notFound('Plan not found');
  const previousValue = plan.toObject();
  plan.isActive = req.path.endsWith('/activate');
  plan.updatedBy = req.user._id;
  await plan.save();
  await recordAudit({
    req,
    user: req.user,
    action: plan.isActive ? 'recharge_plan_activated' : 'recharge_plan_deactivated',
    module: 'plans',
    recordId: plan._id,
    previousValue,
    newValue: plan.toObject(),
  });
  return success(res, { message: `Plan ${plan.isActive ? 'activated' : 'deactivated'}`, data: { plan } });
});

const listMarkets = asyncHandler(async (_req, res) => {
  await normalizeMarketDisplayOrder();
  const now = new Date();
  const markets = await Market.find({ isDeleted: { $ne: true } })
    .populate('createdBy', 'fullName username')
    .sort(marketSort);
  markets.forEach((market) => {
    market.set('availability', serializeMarketStatus(market, now), { strict: false });
  });
  return success(res, { data: { markets } });
});

const upsertMarket = asyncHandler(async (req, res) => {
  const market = req.params.id ? await Market.findById(req.params.id) : new Market({ createdBy: req.user._id });
  if (!market) throw ApiError.notFound('Market not found');
  const previousValue = market.isNew ? null : market.toObject();
  for (const field of ['name', 'code', 'openingTime', 'closingTime', 'resultTime', 'description', 'isActive']) {
    if (req.body[field] !== undefined) market[field] = req.body[field];
  }
  if (!market.createdBy) market.createdBy = req.user._id;
  if (market.isNew) market.displayOrder = await nextMarketDisplayOrder();
  await market.save();
  await recordAudit({
    req,
    user: req.user,
    action: previousValue ? 'market_update' : 'market_creation',
    module: 'markets',
    recordId: market._id,
    previousValue,
    newValue: market.toObject(),
  });
  return success(res, {
    statusCode: previousValue ? 200 : 201,
    message: previousValue ? 'Market updated' : 'Market created',
    data: { market },
  });
});

const reorderMarketList = asyncHandler(async (req, res) => {
  const previousValue = await Market.find({ isDeleted: { $ne: true } })
    .sort(marketSort)
    .select('_id name displayOrder')
    .lean();
  await reorderMarkets(req.body.marketIds);
  const newValue = await Market.find({ isDeleted: { $ne: true } })
    .sort(marketSort)
    .select('_id name displayOrder')
    .lean();
  await recordAudit({
    req,
    user: req.user,
    action: 'market_reordered',
    module: 'markets',
    previousValue,
    newValue,
  });
  return success(res, { message: 'Market order saved' });
});

const setMarketStatus = asyncHandler(async (req, res) => {
  const market = await Market.findById(req.params.id);
  if (!market) throw ApiError.notFound('Market not found');
  const previousValue = market.toObject();
  market.isActive = req.path.endsWith('/activate');
  await market.save();
  await recordAudit({
    req,
    user: req.user,
    action: market.isActive ? 'market_activated' : 'market_deactivated',
    module: 'markets',
    recordId: market._id,
    previousValue,
    newValue: market.toObject(),
  });
  return success(res, { message: `Market ${market.isActive ? 'activated' : 'deactivated'}`, data: { market } });
});

const deleteMarket = asyncHandler(async (req, res) => {
  const market = await Market.findOne({ _id: req.params.id, isDeleted: { $ne: true } });
  if (!market) throw ApiError.notFound('Market not found');
  const previousValue = market.toObject();
  const hasReceipts = await require('../models/Receipt').exists({ market: market._id });
  if (hasReceipts) {
    market.isDeleted = true;
    market.isActive = false;
    market.deletedAt = new Date();
    market.deletedBy = req.user._id;
    await market.save();
  } else {
    await Market.deleteOne({ _id: market._id });
  }
  await User.updateMany(
    { assignedMarkets: market._id },
    { $pull: { assignedMarkets: market._id } },
  );
  await normalizeMarketDisplayOrder();
  logger.info(`Market delete requested market=${market._id} admin=${req.user._id} soft=${!!hasReceipts}`);
  await recordAudit({
    req,
    user: req.user,
    action: hasReceipts ? 'market_soft_deleted' : 'market_deleted',
    module: 'markets',
    recordId: market._id,
    previousValue,
  });
  return success(res, { message: 'Market deleted successfully.' });
});

const numberConfig = asyncHandler(async (req, res) => {
  const { payload, analysis } = standardPannaNumberSetPayload();
  const values = payload.values || [];
  const search = req.query.search?.trim();
  return success(res, {
    data: {
      code: payload.code,
      label: payload.label,
      totalPannaCount: values.length,
      analysis,
      groups: payload.groups || [],
      values: search ? values.filter((item) => item.value.includes(search)) : values,
      readOnly: true,
    },
  });
});

const listAuditLogs = asyncHandler(async (req, res) => {
  const { page, limit, skip } = getPagination(req.query, 25);
  const filter = {};
  if (req.query.user) filter.user = req.query.user;
  if (req.query.action) filter.action = req.query.action;
  if (req.query.module) filter.module = req.query.module;
  const [logs, total] = await Promise.all([
    AuditLog.find(filter)
      .populate('user', 'fullName username email')
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(limit),
    AuditLog.countDocuments(filter),
  ]);
  return success(res, {
    data: { logs },
    pagination: paginationMeta(page, limit, total),
  });
});

const getAdminSettings = asyncHandler(async (_req, res) => {
  const settings = await Settings.getApplicationSettings();
  return success(res, { data: { settings: settings.toSafeObject() } });
});

const updateAdminSettings = asyncHandler(async (req, res) => {
  const settings = await Settings.getApplicationSettings();
  const previousValue = settings.toSafeObject();
  for (const field of [
    'applicationName',
    'subscriptionWarningDays',
    'allowNewRegistrations',
    'requireManualApproval',
    'defaultApprovalStatus',
    'supportMobileNumber',
    'supportWhatsAppNumber',
    'singleDeviceLoginEnabled',
  ]) {
    if (req.body[field] !== undefined) settings[field] = req.body[field];
  }
  settings.updatedBy = req.user._id;
  await settings.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'admin_settings_updated',
    module: 'settings',
    previousValue,
    newValue: settings.toSafeObject(),
  });
  return success(res, { message: 'Admin settings updated', data: { settings: settings.toSafeObject() } });
});

module.exports = {
  dashboard,
  listUsers,
  getUser,
  approveUser,
  rejectUser,
  blockUser,
  unblockUser,
  resetDeviceLogin,
  activateUser,
  disableUser,
  rechargeUser,
  userRecharges,
  listRecharges,
  listPlans,
  createPlan,
  updatePlan,
  setPlanStatus,
  listMarkets,
  upsertMarket,
  reorderMarketList,
  setMarketStatus,
  deleteMarket,
  numberConfig,
  listAuditLogs,
  getAdminSettings,
  updateAdminSettings,
};
