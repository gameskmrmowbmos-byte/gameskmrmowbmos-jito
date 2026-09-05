const dotenv = require('dotenv');
const { getPortFromEnv } = require('../utils/port');

dotenv.config();

const requiredInProduction = [
  'MONGODB_URI',
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'FRONTEND_URL',
];

if (process.env.NODE_ENV === 'production') {
  const missing = requiredInProduction.filter((name) => !process.env[name]);
  if (missing.length) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
}

const splitOrigins = (value) =>
  (value || 'http://localhost:5173,http://localhost:5000')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

module.exports = Object.freeze({
  nodeEnv: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',
  port: getPortFromEnv(process.env.PORT) || 5002,
  host: process.env.HOST || '0.0.0.0',
  mongoUri:
    process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/matka_management',
  accessSecret:
    process.env.JWT_ACCESS_SECRET || 'development_access_secret_change_me_123456',
  refreshSecret:
    process.env.JWT_REFRESH_SECRET || 'development_refresh_secret_change_me_12345',
  accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '30d',
  refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  refreshCookieMaxAgeDays:
    Number(process.env.REFRESH_COOKIE_MAX_AGE_DAYS) || 30,
  allowedOrigins: splitOrigins(process.env.FRONTEND_URL),
  resetPasswordUrl:
    process.env.RESET_PASSWORD_URL || 'http://localhost:5173/reset-password',
  logLevel: process.env.LOG_LEVEL || 'info',
  receiptTimezone: process.env.RECEIPT_TIMEZONE || 'Asia/Kolkata',
  showDevOtp:
    process.env.SHOW_DEV_OTP === 'true' || process.env.NODE_ENV !== 'production',
  otpExpiryMinutes: Number(process.env.OTP_EXPIRY_MINUTES) || 5,
  freeTrialDays: Number(process.env.FREE_TRIAL_DAYS) || 10,
  smtp: {
    host: process.env.SMTP_HOST || '',
    port: Number(process.env.SMTP_PORT) || 587,
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from:
      process.env.SMTP_FROM ||
      'Matka Management Demo <no-reply@example.com>',
  },
});
