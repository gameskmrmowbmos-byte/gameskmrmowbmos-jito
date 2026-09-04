const { validationResult } = require('express-validator');
const ApiError = require('../utils/apiError');
const logger = require('../utils/logger');

function validate(req, _res, next) {
  const result = validationResult(req);
  if (result.isEmpty()) return next();

  logger.warn('Request validation failed', {
    method: req.method,
    path: req.originalUrl,
    fields: result.array().map((error) => error.path),
  });

  return next(
    ApiError.badRequest(
      'Validation failed',
      result.array().map((error) => ({
        field: error.path,
        message: error.msg,
      })),
    ),
  );
}

module.exports = validate;

