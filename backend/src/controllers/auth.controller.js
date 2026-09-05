const env = require('../config/env');
const User = require('../models/User');
const authService = require('../services/auth.service');
const { recordAudit } = require('../services/audit.service');
const {
  sendRegistrationOtp,
  verifyRegistrationOtp,
  sendPasswordResetOtp,
  verifyPasswordResetOtp,
  resetPasswordWithOtp,
} = require('../services/otp.service');
const { getAccessStatus } = require('../services/subscription.service');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { success } = require('../utils/response');

const cookieOptions = {
  httpOnly: true,
  secure: env.isProduction,
  sameSite: env.isProduction ? 'none' : 'lax',
  path: '/api/auth',
  maxAge: 7 * 24 * 60 * 60 * 1000,
};
const clearCookieOptions = {
  httpOnly: cookieOptions.httpOnly,
  secure: cookieOptions.secure,
  sameSite: cookieOptions.sameSite,
  path: cookieOptions.path,
};

function tokenResponse(req, user, tokens) {
  const isWeb = req.get('x-client-platform') === 'web';
  return {
    user: user.toSafeObject(),
    accessStatus: getAccessStatus(user),
    accessToken: tokens.accessToken,
    ...(isWeb ? {} : { refreshToken: tokens.refreshToken }),
  };
}

const login = asyncHandler(async (req, res) => {
  try {
    const { user, tokens } = await authService.authenticate(
      req.body.identifier,
      req.body.password,
      { deviceId: req.body.deviceId },
    );
    user.loginHistory = [
      ...(user.loginHistory || []).slice(-49),
      {
        successful: true,
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      },
    ];
    await user.save({ validateBeforeSave: false });
    res.cookie('refreshToken', tokens.refreshToken, cookieOptions);
    await recordAudit({ req, user, action: 'login', module: 'auth' });
    return success(res, {
      message: 'Login successful',
      data: tokenResponse(req, user, tokens),
    });
  } catch (error) {
    await recordAudit({
      req,
      action: 'failed_login',
      module: 'auth',
      metadata: { identifier: req.body.identifier },
    });
    throw error;
  }
});

const sendRegisterOtp = asyncHandler(async (req, res) => {
  const result = await sendRegistrationOtp({
    fullName: req.body.fullName,
    ownerName: req.body.ownerName,
    email: req.body.email,
    phoneNumber: req.body.phoneNumber,
    password: req.body.password,
    req,
  });
  return success(res, {
    message: 'OTP sent. Please verify your email to create the account.',
    data: result,
  });
});

const verifyRegisterOtp = asyncHandler(async (req, res) => {
  const user = await verifyRegistrationOtp({
    email: req.body.email,
    otp: req.body.otp,
  });
  await recordAudit({
    req,
    user,
    action: 'register',
    module: 'auth',
  });
  return success(res, {
    statusCode: 201,
    message:
      'Registration completed successfully. Your account is waiting for administrator approval.',
    data: { user: user.toSafeObject() },
  });
});

const refresh = asyncHandler(async (req, res) => {
  const rawToken = req.cookies.refreshToken || req.body.refreshToken;
  if (!rawToken) throw ApiError.unauthorized('Refresh token is required');

  const { user, tokens } = await authService.rotateRefreshToken(rawToken);
  res.cookie('refreshToken', tokens.refreshToken, cookieOptions);
  return success(res, {
    message: 'Session refreshed',
    data: tokenResponse(req, user, tokens),
  });
});

const logout = asyncHandler(async (req, res) => {
  const rawToken = req.cookies.refreshToken || req.body.refreshToken;
  await authService.invalidateRefreshToken(rawToken);
  res.clearCookie('refreshToken', clearCookieOptions);
  await recordAudit({
    req,
    user: req.user,
    action: 'logout',
    module: 'auth',
  });
  return success(res, { message: 'Logout successful' });
});

const me = asyncHandler(async (req, res) =>
  success(res, {
    data: {
      user: req.user.toSafeObject(),
      accessStatus: getAccessStatus(req.user),
    },
  }),
);

const forgotPassword = asyncHandler(async (req, res) => {
  const data = await sendPasswordResetOtp({ email: req.body.email, req });
  return success(res, {
    message:
      'If an account exists for this email, a verification code has been generated.',
    data,
  });
});

const verifyForgotPasswordOtp = asyncHandler(async (req, res) => {
  await verifyPasswordResetOtp({ email: req.body.email, otp: req.body.otp });
  return success(res, { message: 'OTP verified. You can reset your password.' });
});

const resetPassword = asyncHandler(async (req, res) => {
  const user = await resetPasswordWithOtp({
    email: req.body.email,
    otp: req.body.otp,
    password: req.body.password,
  });
  await recordAudit({
    req,
    user,
    action: 'password_reset',
    module: 'auth',
  });
  return success(res, {
    message: 'Password reset successful. Please log in again.',
  });
});

const changePassword = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user._id).select(
    '+passwordHash +refreshTokenHash',
  );
  if (!(await user.verifyPassword(req.body.currentPassword))) {
    throw ApiError.badRequest('Current password is incorrect');
  }
  await user.setPassword(req.body.password);
  user.refreshTokenHash = undefined;
  await user.save();
  res.clearCookie('refreshToken', clearCookieOptions);
  await recordAudit({
    req,
    user,
    action: 'password_changed',
    module: 'auth',
  });
  return success(res, {
    message: 'Password changed. Please log in with the new password.',
  });
});

module.exports = {
  sendRegisterOtp,
  verifyRegisterOtp,
  login,
  refresh,
  logout,
  me,
  forgotPassword,
  verifyForgotPasswordOtp,
  resetPassword,
  changePassword,
};
