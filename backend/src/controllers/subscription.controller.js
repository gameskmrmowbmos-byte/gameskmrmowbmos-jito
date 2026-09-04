const asyncHandler = require('../utils/asyncHandler');
const { success } = require('../utils/response');
const { getAccessStatus } = require('../services/subscription.service');

const getStatus = asyncHandler(async (req, res) =>
  success(res, {
    data: getAccessStatus(req.user),
  }),
);

module.exports = { getStatus };
