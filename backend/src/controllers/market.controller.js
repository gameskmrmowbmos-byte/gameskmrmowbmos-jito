const Market = require('../models/Market');
const Receipt = require('../models/Receipt');
const { recordAudit } = require('../services/audit.service');
const { serializeMarketStatus } = require('../services/marketAvailability.service');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { getPagination, paginationMeta } = require('../utils/pagination');
const { success } = require('../utils/response');
const {
  marketSort,
  nextMarketDisplayOrder,
  normalizeMarketDisplayOrder,
} = require('../services/marketOrder.service');

function marketScope(req) {
  if (req.user.role === 'admin') return {};
  const assignedMarkets = req.user.assignedMarkets || [];
  if (assignedMarkets.length === 0) {
    return {
      isActive: true,
      isDeleted: { $ne: true },
    };
  }
  return {
    _id: { $in: assignedMarkets },
    isActive: true,
    isDeleted: { $ne: true },
  };
}

const listMarkets = asyncHandler(async (req, res) => {
  await normalizeMarketDisplayOrder();
  const { page, limit, skip } = getPagination(req.query, 50);
  const filter = { ...marketScope(req), isDeleted: { $ne: true } };
  if (req.query.status === 'active') filter.isActive = true;
  if (req.query.status === 'inactive' && req.user.role === 'admin') {
    filter.isActive = false;
  }
  if (req.query.search) {
    const escaped = req.query.search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    filter.$or = [
      { name: { $regex: escaped, $options: 'i' } },
      { code: { $regex: escaped, $options: 'i' } },
    ];
  }
  const [markets, total] = await Promise.all([
    Market.find(filter)
      .populate('createdBy', 'fullName username')
      .sort(marketSort)
      .skip(skip)
      .limit(limit),
    Market.countDocuments(filter),
  ]);
  const now = new Date();
  markets.forEach((market) => {
    market.set('availability', serializeMarketStatus(market, now), { strict: false });
  });
  return success(res, {
    data: { markets },
    pagination: paginationMeta(page, limit, total),
  });
});

const getMarket = asyncHandler(async (req, res) => {
  const market = await Market.findOne({
    $and: [{ _id: req.params.id }, marketScope(req)],
  }).populate('createdBy', 'fullName username');
  if (!market) throw ApiError.notFound('Market not found');
  return success(res, { data: { market } });
});

const createMarket = asyncHandler(async (req, res) => {
  const {
    name,
    code,
    openingTime,
    closingTime,
    resultTime,
    description,
    isActive,
    gameConfigCode,
  } = req.body;
  const market = await Market.create({
    name,
    code,
    openingTime,
    closingTime,
    resultTime,
    description,
    isActive,
    gameConfigCode,
    displayOrder: await nextMarketDisplayOrder(),
    createdBy: req.user._id,
  });
  await recordAudit({
    req,
    user: req.user,
    action: 'market_creation',
    module: 'markets',
    recordId: market._id,
    newValue: market.toObject(),
  });
  return success(res, {
    statusCode: 201,
    message: 'Market created',
    data: { market },
  });
});

const updateMarket = asyncHandler(async (req, res) => {
  const market = await Market.findById(req.params.id);
  if (!market) throw ApiError.notFound('Market not found');
  const previousValue = market.toObject();
  for (const field of [
    'name',
    'code',
    'openingTime',
    'closingTime',
    'resultTime',
    'description',
    'isActive',
    'gameConfigCode',
  ]) {
    if (req.body[field] !== undefined) market[field] = req.body[field];
  }
  await market.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'market_update',
    module: 'markets',
    recordId: market._id,
    previousValue,
    newValue: market.toObject(),
  });
  return success(res, { message: 'Market updated', data: { market } });
});

const updateStatus = asyncHandler(async (req, res) => {
  const market = await Market.findById(req.params.id);
  if (!market) throw ApiError.notFound('Market not found');
  const oldStatus = market.isActive;
  market.isActive = Boolean(req.body.isActive);
  await market.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'market_status_update',
    module: 'markets',
    recordId: market._id,
    previousValue: { isActive: oldStatus },
    newValue: { isActive: market.isActive },
  });
  return success(res, {
    message: `Market ${market.isActive ? 'activated' : 'deactivated'}`,
    data: { market },
  });
});

const deleteMarket = asyncHandler(async (req, res) => {
  const hasReceipts = await Receipt.exists({ market: req.params.id });
  if (hasReceipts) {
    throw ApiError.conflict(
      'Market has entry history and cannot be deleted; deactivate it instead',
    );
  }
  const market = await Market.findByIdAndDelete(req.params.id);
  if (!market) throw ApiError.notFound('Market not found');
  await normalizeMarketDisplayOrder();
  await recordAudit({
    req,
    user: req.user,
    action: 'market_deletion',
    module: 'markets',
    recordId: market._id,
    previousValue: market.toObject(),
  });
  return success(res, { message: 'Market deleted' });
});

module.exports = {
  listMarkets,
  getMarket,
  createMarket,
  updateMarket,
  updateStatus,
  deleteMarket,
};
