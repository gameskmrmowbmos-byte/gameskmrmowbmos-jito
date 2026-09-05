const ApiError = require('../utils/apiError');

function getMarketStatus(market, serverNow = new Date()) {
  if (!market || market.isDeleted) {
    return {
      state: 'DELETED',
      canEnter: false,
      code: 'MARKET_NOT_FOUND',
      message: 'Market is no longer available.',
    };
  }
  if (market.isActive === false) {
    return {
      state: 'INACTIVE',
      canEnter: false,
      code: 'MARKET_INACTIVE',
      message: 'This market is inactive.',
    };
  }

  return {
    state: 'OPEN',
    canEnter: true,
    code: null,
    message: 'Market is available.',
    serverTime: serverNow,
  };
}

function assertMarketOpen(market, serverNow = new Date()) {
  const status = getMarketStatus(market, serverNow);
  if (!status.canEnter) {
    throw ApiError.forbidden(status.message, status.code);
  }
  return status;
}

function serializeMarketStatus(market, serverNow = new Date()) {
  const status = getMarketStatus(market, serverNow);
  return {
    ...status,
    serverTime: serverNow.toISOString(),
  };
}

module.exports = {
  assertMarketOpen,
  getMarketStatus,
  serializeMarketStatus,
};
