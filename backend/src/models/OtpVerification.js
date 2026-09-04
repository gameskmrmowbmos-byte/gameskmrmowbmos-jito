const mongoose = require('mongoose');

const otpVerificationSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
      index: true,
    },
    phoneNumber: { type: String, trim: true, maxlength: 20 },
    fullName: { type: String, trim: true, maxlength: 100 },
    passwordHash: { type: String, select: false },
    otpHash: { type: String, required: true, select: false },
    purpose: {
      type: String,
      enum: ['REGISTRATION', 'PASSWORD_RESET'],
      required: true,
      index: true,
    },
    expiresAt: { type: Date, required: true },
    verified: { type: Boolean, default: false, index: true },
    used: { type: Boolean, default: false, index: true },
    attempts: { type: Number, default: 0, min: 0, max: 5 },
    ipAddress: { type: String },
    userAgent: { type: String },
  },
  { timestamps: true },
);

otpVerificationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
otpVerificationSchema.index({ email: 1, purpose: 1, createdAt: -1 });

module.exports = mongoose.model('OtpVerification', otpVerificationSchema);
