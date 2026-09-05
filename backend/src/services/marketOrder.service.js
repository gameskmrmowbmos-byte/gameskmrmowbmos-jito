const Market = require('../models/Market');
const ApiError = require('../utils/apiError');

const marketSort = { displayOrder: 1, createdAt: 1, name: 1 };

async function nextMarketDisplayOrder() {
  await normalizeMarketDisplayOrder();
  const lastMarket = await Market.findOne({ isDeleted: { $ne: true } })
    .sort({ displayOrder: -1, createdAt: -1 })
    .select('displayOrder');
  return (lastMarket?.displayOrder || 0) + 1;
}

async function normalizeMarketDisplayOrder() {
  const markets = await Market.find({ isDeleted: { $ne: true } })
    .sort(marketSort)
    .select('_id displayOrder');
  const operations = [];
  for (let index = 0; index < markets.length; index += 1) {
    const displayOrder = index + 1;
    if (markets[index].displayOrder !== displayOrder) {
      operations.push({
        updateOne: {
          filter: { _id: markets[index]._id },
          update: { $set: { displayOrder } },
        },
      });
    }
  }
  if (operations.length) await Market.bulkWrite(operations, { ordered: true });
}

async function reorderMarkets(marketIds) {
  if (!Array.isArray(marketIds) || marketIds.length === 0) {
    throw ApiError.badRequest('marketIds must be a non-empty array');
  }

  const uniqueIds = new Set(marketIds.map((id) => `${id}`));
  if (uniqueIds.size !== marketIds.length) {
    throw ApiError.badRequest('Market IDs must be unique');
  }

  const markets = await Market.find({ isDeleted: { $ne: true } }).select('_id');
  const existingIds = new Set(markets.map((market) => market._id.toString()));
  if (existingIds.size !== marketIds.length) {
    throw ApiError.badRequest('Reorder request must include every non-deleted market');
  }

  for (const id of marketIds) {
    if (!existingIds.has(`${id}`)) {
      throw ApiError.badRequest('Reorder request contains an invalid market ID');
    }
  }

  await Market.bulkWrite(
    marketIds.map((id, index) => ({
      updateOne: {
        filter: { _id: id, isDeleted: { $ne: true } },
        update: { $set: { displayOrder: index + 1 } },
      },
    })),
    { ordered: true },
  );
}

module.exports = {
  marketSort,
  nextMarketDisplayOrder,
  normalizeMarketDisplayOrder,
  reorderMarkets,
};
