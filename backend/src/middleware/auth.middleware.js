const User = require('../models/User');
const tokenService = require('../services/token.service');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');

const authenticate = asyncHandler(async (req, _res, next) => {
  const authorization = req.get('authorization') || '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    throw ApiError.unauthorized('A valid Bearer access token is required');
  }

  const payload = tokenService.verifyAccessToken(token);
  const user = await User.findById(payload.sub).select('+tokenVersion');
  if (!user) throw ApiError.unauthorized('Token user no longer exists');
  if (!user.isActive) throw ApiError.forbidden('This account is inactive');
  if (user.role !== 'admin' && user.accountStatus === 'DISABLED') {
    throw ApiError.forbidden('This account is disabled', 'ACCOUNT_DISABLED');
  }
  if (user.role !== 'admin' && (user.approvalStatus || 'APPROVED') === 'PENDING') {
    throw ApiError.forbidden(
      'Your account is awaiting administrator approval.',
      'ACCOUNT_PENDING_APPROVAL',
    );
  }
  if (user.role !== 'admin' && user.approvalStatus === 'REJECTED') {
    throw ApiError.forbidden('Your account was not approved.', 'ACCOUNT_REJECTED');
  }
  if ((user.tokenVersion || 0) !== (payload.tokenVersion || 0)) {
    throw ApiError.unauthorized(
      'Your login session has been reset by the administrator. Please login again.',
      'SESSION_REVOKED',
    );
  }

  req.user = user;
  next();
});

module.exports = authenticate;

