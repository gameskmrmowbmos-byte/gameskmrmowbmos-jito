const express = require('express');
const controller = require('../controllers/auth.controller');
const authenticate = require('../middleware/auth.middleware');
const {
  loginLimiter,
  passwordResetLimiter,
  otpLimiter,
} = require('../middleware/rateLimit.middleware');
const validate = require('../middleware/validate.middleware');
const {
  loginRules,
  registrationOtpRules,
  otpVerifyRules,
  refreshRules,
  forgotPasswordRules,
  resetPasswordRules,
  changePasswordRules,
} = require('../validators/auth.validator');

const router = express.Router();

router.post(
  '/register/send-otp',
  otpLimiter,
  registrationOtpRules,
  validate,
  controller.sendRegisterOtp,
);
router.post(
  '/register/verify-otp',
  otpVerifyRules,
  validate,
  controller.verifyRegisterOtp,
);
router.post('/login', loginLimiter, loginRules, validate, controller.login);
router.post('/refresh', refreshRules, validate, controller.refresh);
router.post('/logout', refreshRules, validate, controller.logout);
router.post(
  '/forgot-password',
  otpLimiter,
  forgotPasswordRules,
  validate,
  controller.forgotPassword,
);
router.post(
  '/forgot-password/verify-otp',
  passwordResetLimiter,
  otpVerifyRules,
  validate,
  controller.verifyForgotPasswordOtp,
);
router.post(
  '/reset-password',
  passwordResetLimiter,
  resetPasswordRules,
  validate,
  controller.resetPassword,
);
router.post(
  '/change-password',
  authenticate,
  changePasswordRules,
  validate,
  controller.changePassword,
);
router.get('/me', authenticate, controller.me);

module.exports = router;

