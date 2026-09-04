const User = require('../models/User');
const { recordAudit } = require('../services/audit.service');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { getPagination, paginationMeta } = require('../utils/pagination');
const { success } = require('../utils/response');

const listUsers = asyncHandler(async (req, res) => {
  const { page, limit, skip } = getPagination(req.query);
  const filter = { role: 'operator', isDeleted: { $ne: true } };
  if (req.query.status === 'active') filter.isActive = true;
  if (req.query.status === 'inactive') filter.isActive = false;
  if (req.query.search) {
    const escaped = req.query.search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    filter.$or = [
      { fullName: { $regex: escaped, $options: 'i' } },
      { username: { $regex: escaped, $options: 'i' } },
      { email: { $regex: escaped, $options: 'i' } },
    ];
  }

  const [users, total] = await Promise.all([
    User.find(filter)
      .populate('assignedMarkets', 'name code')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    User.countDocuments(filter),
  ]);
  return success(res, {
    data: { users },
    pagination: paginationMeta(page, limit, total),
  });
});

const getUser = asyncHandler(async (req, res) => {
  const user = await User.findOne({ _id: req.params.id, role: 'operator', isDeleted: { $ne: true } })
    .populate('assignedMarkets', 'name code')
    .select('+loginHistory');
  if (!user) throw ApiError.notFound('Operator not found');
  return success(res, { data: { user } });
});

const createUser = asyncHandler(async (req, res) => {
  const user = new User({
    fullName: req.body.fullName,
    username: req.body.username,
    email: req.body.email,
    phoneNumber: req.body.phoneNumber,
    role: 'operator',
    assignedMarkets: req.body.assignedMarkets || [],
    isActive: req.body.isActive ?? true,
    emailVerified: true,
    approvalStatus: 'APPROVED',
    accountStatus: 'ACTIVE',
    passwordHash: 'pending',
  });
  await user.setPassword(req.body.password);
  await user.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'user_creation',
    module: 'users',
    recordId: user._id,
    newValue: user.toSafeObject(),
  });
  return success(res, {
    statusCode: 201,
    message: 'Operator created',
    data: { user: user.toSafeObject() },
  });
});

const updateUser = asyncHandler(async (req, res) => {
  const user = await User.findOne({ _id: req.params.id, role: 'operator', isDeleted: { $ne: true } }).select(
    '+passwordHash +refreshTokenHash',
  );
  if (!user) throw ApiError.notFound('Operator not found');
  const previousValue = user.toSafeObject();

  for (const field of [
    'fullName',
    'username',
    'email',
    'phoneNumber',
    'assignedMarkets',
    'isActive',
  ]) {
    if (req.body[field] !== undefined) user[field] = req.body[field];
  }
  if (req.body.password) {
    await user.setPassword(req.body.password);
    user.refreshTokenHash = undefined;
  }
  await user.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'user_update',
    module: 'users',
    recordId: user._id,
    previousValue,
    newValue: user.toSafeObject(),
  });
  return success(res, {
    message: 'Operator updated',
    data: { user: user.toSafeObject() },
  });
});

const updateStatus = asyncHandler(async (req, res) => {
  const user = await User.findOne({ _id: req.params.id, role: 'operator', isDeleted: { $ne: true } }).select(
    '+refreshTokenHash',
  );
  if (!user) throw ApiError.notFound('Operator not found');
  const oldStatus = user.isActive;
  user.isActive = Boolean(req.body.isActive);
  if (!user.isActive) user.refreshTokenHash = undefined;
  await user.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'user_status_update',
    module: 'users',
    recordId: user._id,
    previousValue: { isActive: oldStatus },
    newValue: { isActive: user.isActive },
  });
  return success(res, {
    message: `Operator ${user.isActive ? 'activated' : 'deactivated'}`,
    data: { user: user.toSafeObject() },
  });
});

const resetUserPassword = asyncHandler(async (req, res) => {
  const user = await User.findOne({ _id: req.params.id, role: 'operator' }).select(
    '+passwordHash +refreshTokenHash',
  );
  if (!user) throw ApiError.notFound('Operator not found');
  await user.setPassword(req.body.password);
  user.refreshTokenHash = undefined;
  await user.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'operator_password_reset',
    module: 'users',
    recordId: user._id,
  });
  return success(res, { message: 'Operator password reset successfully' });
});

const deleteUser = asyncHandler(async (req, res) => {
  const user = await User.findOne({
    _id: req.params.id,
    role: 'operator',
    isDeleted: { $ne: true },
  }).select('+refreshTokenHash +tokenVersion');
  if (!user) throw ApiError.notFound('Operator not found');
  user.isActive = false;
  user.accountStatus = 'DISABLED';
  user.isDeleted = true;
  user.deletedAt = new Date();
  user.deletedBy = req.user._id;
  user.refreshTokenHash = undefined;
  user.tokenVersion = (user.tokenVersion || 0) + 1;
  await user.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'user_deletion',
    module: 'users',
    recordId: user._id,
    previousValue: user.toSafeObject(),
  });
  return success(res, { message: 'Operator deactivated and archived' });
});

module.exports = {
  listUsers,
  getUser,
  createUser,
  updateUser,
  updateStatus,
  resetUserPassword,
  deleteUser,
};

