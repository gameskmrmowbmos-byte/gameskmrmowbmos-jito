const { body } = require('express-validator');

const strongPassword = body('password')
  .isLength({ min: 8, max: 128 })
  .withMessage('Password must be between 8 and 128 characters')
  .matches(/[a-z]/)
  .withMessage('Password must contain a lowercase letter')
  .matches(/[A-Z]/)
  .withMessage('Password must contain an uppercase letter')
  .matches(/\d/)
  .withMessage('Password must contain a number')
  .matches(/[^A-Za-z0-9]/)
  .withMessage('Password must contain a special character');

const loginRules = [
  body('identifier')
    .trim()
    .notEmpty()
    .withMessage('Email or username is required')
    .isLength({ max: 120 })
    .withMessage('Identifier is too long'),
  body('password').isString().notEmpty().withMessage('Password is required'),
  body('deviceId')
    .optional()
    .isString()
    .isLength({ min: 16, max: 128 })
    .withMessage('Device identifier is invalid'),
];

const registrationOtpRules = [
  body('fullName')
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Full name must contain at least 2 characters'),
  body('email')
    .trim()
    .isEmail()
    .withMessage('Valid email is required')
    .normalizeEmail(),
  body('phoneNumber')
    .trim()
    .matches(/^[6-9]\d{9}$/)
    .withMessage('Enter a valid 10-digit Indian mobile number'),
  strongPassword,
  body('confirmPassword').custom((value, { req }) => {
    if (value !== req.body.password) throw new Error('Passwords do not match');
    return true;
  }),
];

const otpVerifyRules = [
  body('email')
    .trim()
    .isEmail()
    .withMessage('Valid email is required')
    .normalizeEmail(),
  body('otp')
    .trim()
    .matches(/^\d{6}$/)
    .withMessage('Enter the 6-digit OTP'),
];

const refreshRules = [
  body('refreshToken')
    .optional()
    .isString()
    .withMessage('Refresh token must be a string'),
];

const forgotPasswordRules = [
  body('email').trim().isEmail().withMessage('Valid email is required').normalizeEmail(),
];

const resetPasswordRules = [
  body('email')
    .trim()
    .isEmail()
    .withMessage('Valid email is required')
    .normalizeEmail(),
  body('otp')
    .trim()
    .matches(/^\d{6}$/)
    .withMessage('Enter the 6-digit OTP'),
  strongPassword,
  body('confirmPassword').optional().custom((value, { req }) => {
    if (value !== req.body.password) throw new Error('Passwords do not match');
    return true;
  }),
];

const changePasswordRules = [
  body('currentPassword')
    .isString()
    .notEmpty()
    .withMessage('Current password is required'),
  strongPassword,
];

module.exports = {
  loginRules,
  registrationOtpRules,
  otpVerifyRules,
  refreshRules,
  forgotPasswordRules,
  resetPasswordRules,
  changePasswordRules,
};

