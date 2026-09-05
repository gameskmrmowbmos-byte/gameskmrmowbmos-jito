class ApiError extends Error {
  constructor(statusCode, message, errors = [], code) {
    super(message);
    this.name = 'ApiError';
    this.statusCode = statusCode;
    this.errors = errors;
    this.code = code;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }

  static badRequest(message, errors = [], code) {
    return new ApiError(400, message, errors, code);
  }

  static unauthorized(message = 'Authentication required', code) {
    return new ApiError(401, message, [], code);
  }

  static forbidden(
    message = 'You do not have permission to perform this action',
    code,
  ) {
    return new ApiError(403, message, [], code);
  }

  static notFound(message = 'Resource not found') {
    return new ApiError(404, message);
  }

  static conflict(message) {
    return new ApiError(409, message);
  }
}

module.exports = ApiError;

