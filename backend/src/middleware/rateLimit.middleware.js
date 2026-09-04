const rateLimit = require('express-rate-limit');

const standardHandler = (_req, res, _next, options) =>
  res.status(options.statusCode).json({
    success: false,
    code: 'RATE_LIMITED',
    message: options.message,
    errors: [],
  });

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 500,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: 'Too many requests. Please try again later.',
  handler: standardHandler,
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  skipSuccessfulRequests: true,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: 'Too many login attempts. Please try again after 15 minutes.',
  handler: standardHandler,
});

const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: 'Too many password reset requests. Please try again later.',
  handler: standardHandler,
});

const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: 'Too many OTP requests. Please try again after 15 minutes.',
  handler: standardHandler,
});

module.exports = { apiLimiter, loginLimiter, passwordResetLimiter, otpLimiter };

