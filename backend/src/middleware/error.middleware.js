const mongoose = require('mongoose');
const ApiError = require('../utils/apiError');
const env = require('../config/env');
const logger = require('../utils/logger');

function notFound(req, _res, next) {
  next(ApiError.notFound(`Route ${req.method} ${req.originalUrl} was not found`));
}

function errorHandler(error, req, res, _next) {
  let normalized = error;

  if (error instanceof mongoose.Error.ValidationError) {
    normalized = ApiError.badRequest(
      'Validation failed',
      Object.values(error.errors).map((item) => ({
        field: item.path,
        message: item.message,
      })),
    );
  } else if (error?.code === 11000) {
    const field = Object.keys(error.keyPattern || error.keyValue || {})[0];
    normalized = ApiError.conflict(
      field ? `${field} is already in use` : 'Duplicate record',
    );
  } else if (error instanceof mongoose.Error.CastError) {
    normalized = ApiError.badRequest(`Invalid ${error.path}`);
  }

  const statusCode = normalized.statusCode || 500;
  if (statusCode >= 500) {
    logger.error('Unhandled request error', {
      method: req.method,
      path: req.originalUrl,
      message: error.message,
      stack: env.isProduction ? undefined : error.stack,
    });
  }

  res.status(statusCode).json({
    success: false,
    code: normalized.code,
    message:
      statusCode === 500 && env.isProduction
        ? 'An unexpected server error occurred'
        : normalized.message || 'An unexpected server error occurred',
    errors: normalized.errors || [],
    ...(env.isProduction || statusCode < 500 ? {} : { stack: error.stack }),
  });
}

module.exports = { notFound, errorHandler };

