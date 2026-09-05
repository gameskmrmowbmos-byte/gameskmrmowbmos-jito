const ApiError = require('../utils/apiError');

const requireAdmin = (req, _res, next) => {
  if (!req.user || req.user.role !== 'admin') {
    return next(ApiError.forbidden('Admin access is required', 'ADMIN_REQUIRED'));
  }
  return next();
};

module.exports = requireAdmin;
