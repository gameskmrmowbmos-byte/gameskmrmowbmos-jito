const asyncHandler = require('../utils/asyncHandler');
const { success } = require('../utils/response');
const {
  loadConfigForMarket,
  serializeGameConfig,
} = require('../services/gameConfig.service');

const current = asyncHandler(async (req, res) => {
  const { market } = req.query;
  if (!market) {
    return success(res, {
      data: {
        gameConfig: null,
        message: 'Market is required to resolve the current game configuration',
      },
    });
  }

  const { gameConfig, numberSet } = await loadConfigForMarket(market, req.user);
  return success(res, {
    data: {
      gameConfig: serializeGameConfig(gameConfig, numberSet),
    },
  });
});

module.exports = { current };
