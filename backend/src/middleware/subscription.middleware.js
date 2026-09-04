const asyncHandler = require('../utils/asyncHandler');
const { assertFlutterAccess } = require('../services/subscription.service');

const requireActiveSubscription = asyncHandler(async (req, _res, next) => {
  assertFlutterAccess(req.user);
  next();
});

module.exports = requireActiveSubscription;
