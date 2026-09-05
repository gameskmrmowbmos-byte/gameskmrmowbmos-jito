const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');

const loginHistorySchema = new mongoose.Schema(
  {
    successful: { type: Boolean, required: true },
    ipAddress: String,
    userAgent: String,
    attemptedAt: { type: Date, default: Date.now },
  },
  { _id: false },
);

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: true,
      trim: true,
      minlength: 2,
      maxlength: 100,
    },
    ownerName: {
      type: String,
      trim: true,
      minlength: 2,
      maxlength: 10,
    },
    username: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
      minlength: 3,
      maxlength: 40,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
    },
    phoneNumber: {
      type: String,
      trim: true,
      maxlength: 20,
      unique: true,
      sparse: true,
    },
    passwordHash: { type: String, required: true, select: false },
    emailVerified: { type: Boolean, default: false, index: true },
    role: {
      type: String,
      enum: ['admin', 'operator'],
      default: 'operator',
      index: true,
    },
    approvalStatus: {
      type: String,
      enum: ['PENDING', 'APPROVED', 'REJECTED'],
      default: 'APPROVED',
      index: true,
    },
    approvedAt: Date,
    approvedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    accountStatus: {
      type: String,
      enum: ['ACTIVE', 'BLOCKED', 'DISABLED'],
      default: 'ACTIVE',
      index: true,
    },
    entryAccessBlocked: { type: Boolean, default: false, index: true },
    blockedAt: Date,
    blockedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    blockReason: { type: String, trim: true, maxlength: 500 },
    subscriptionStatus: {
      type: String,
      enum: ['ACTIVE', 'EXPIRED', 'NOT_ACTIVE'],
      default: 'NOT_ACTIVE',
      index: true,
    },
    subscriptionType: {
      type: String,
      enum: ['TRIAL', 'PAID', 'NONE'],
      default: 'NONE',
      index: true,
    },
    subscriptionStartDate: Date,
    subscriptionExpiryDate: { type: Date, index: true },
    trialStartDate: Date,
    trialEndDate: Date,
    rechargeStartDate: Date,
    rechargeEndDate: Date,
    currentPlanId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'RechargePlan',
    },
    assignedMarkets: [
      { type: mongoose.Schema.Types.ObjectId, ref: 'Market' },
    ],
    isActive: { type: Boolean, default: true, index: true },
    isDeleted: { type: Boolean, default: false, index: true },
    deletedAt: Date,
    deletedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    lastLogin: Date,
    loginHistory: { type: [loginHistorySchema], default: [], select: false },
    failedLoginAttempts: { type: Number, default: 0, select: false },
    lockUntil: { type: Date, select: false },
    refreshTokenHash: { type: String, select: false },
    tokenVersion: { type: Number, default: 0, select: false },
    activeDeviceIdHash: { type: String, select: false },
    activeDeviceIdMasked: String,
    activeDeviceBoundAt: Date,
    activeDeviceLastSeenAt: Date,
    deviceResetAt: Date,
    deviceResetBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    passwordResetTokenHash: { type: String, select: false },
    passwordResetExpires: { type: Date, select: false },
    passwordChangedAt: Date,
  },
  { timestamps: true },
);

userSchema.index({ fullName: 'text', username: 'text', email: 'text' });

userSchema.methods.verifyPassword = function verifyPassword(password) {
  return bcrypt.compare(password, this.passwordHash);
};

userSchema.methods.setPassword = async function setPassword(password) {
  this.passwordHash = await bcrypt.hash(password, 12);
  this.passwordChangedAt = new Date();
};

userSchema.methods.setRefreshToken = function setRefreshToken(token) {
  this.refreshTokenHash = crypto.createHash('sha256').update(token).digest('hex');
};

userSchema.methods.deviceHash = function deviceHash(deviceId) {
  return crypto.createHash('sha256').update(`${deviceId}`).digest('hex');
};

userSchema.methods.bindDevice = function bindDevice(deviceId) {
  this.activeDeviceIdHash = this.deviceHash(deviceId);
  this.activeDeviceIdMasked = `****${`${deviceId}`.slice(-4).toUpperCase()}`;
  this.activeDeviceBoundAt = this.activeDeviceBoundAt || new Date();
  this.activeDeviceLastSeenAt = new Date();
};

userSchema.methods.matchesDevice = function matchesDevice(deviceId) {
  const hash = this.deviceHash(deviceId);
  if (!this.activeDeviceIdHash || this.activeDeviceIdHash.length !== hash.length) {
    return false;
  }
  return crypto.timingSafeEqual(
    Buffer.from(this.activeDeviceIdHash),
    Buffer.from(hash),
  );
};

userSchema.methods.matchesRefreshToken = function matchesRefreshToken(token) {
  const hash = crypto.createHash('sha256').update(token).digest('hex');
  if (!this.refreshTokenHash || this.refreshTokenHash.length !== hash.length) {
    return false;
  }
  return crypto.timingSafeEqual(
    Buffer.from(this.refreshTokenHash),
    Buffer.from(hash),
  );
};

userSchema.methods.createPasswordResetToken = function createPasswordResetToken() {
  const rawToken = crypto.randomBytes(32).toString('hex');
  this.passwordResetTokenHash = crypto
    .createHash('sha256')
    .update(rawToken)
    .digest('hex');
  this.passwordResetExpires = Date.now() + 30 * 60 * 1000;
  return rawToken;
};

userSchema.methods.toSafeObject = function toSafeObject() {
  return {
    id: this._id,
    fullName: this.fullName,
    ownerName: this.ownerName,
    username: this.username,
    email: this.email,
    phoneNumber: this.phoneNumber,
    role: this.role,
    emailVerified: this.emailVerified,
    approvalStatus: this.approvalStatus,
    approvedAt: this.approvedAt,
    approvedBy: this.approvedBy,
    accountStatus: this.accountStatus,
    entryAccessBlocked: this.entryAccessBlocked,
    blockedAt: this.blockedAt,
    blockedBy: this.blockedBy,
    blockReason: this.blockReason,
    subscriptionStatus: this.subscriptionStatus,
    subscriptionType: this.subscriptionType,
    subscriptionStartDate: this.subscriptionStartDate,
    subscriptionExpiryDate: this.subscriptionExpiryDate,
    trialStartDate: this.trialStartDate,
    trialEndDate: this.trialEndDate,
    rechargeStartDate: this.rechargeStartDate,
    rechargeEndDate: this.rechargeEndDate,
    currentPlanId: this.currentPlanId,
    assignedMarkets: this.assignedMarkets,
    isActive: this.isActive,
    lastLogin: this.lastLogin,
    activeDeviceIdMasked: this.activeDeviceIdMasked,
    activeDeviceBoundAt: this.activeDeviceBoundAt,
    activeDeviceLastSeenAt: this.activeDeviceLastSeenAt,
    deviceResetAt: this.deviceResetAt,
    deviceResetBy: this.deviceResetBy,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

module.exports = mongoose.model('User', userSchema);

