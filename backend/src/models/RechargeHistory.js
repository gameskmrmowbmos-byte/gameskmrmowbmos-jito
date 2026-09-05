const mongoose = require('mongoose');

const rechargeHistorySchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    plan: { type: mongoose.Schema.Types.ObjectId, ref: 'RechargePlan' },
    planName: { type: String, trim: true, maxlength: 100 },
    validityDays: { type: Number, min: 1, max: 3650 },
    amount: { type: Number, required: true, min: 0 },
    startDate: { type: Date, required: true, index: true },
    expiryDate: { type: Date, required: true, index: true },
    status: {
      type: String,
      enum: ['ACTIVE', 'EXPIRED', 'CANCELLED'],
      default: 'ACTIVE',
      index: true,
    },
    rechargeType: {
      type: String,
      enum: ['PLAN', 'CUSTOM'],
      default: 'CUSTOM',
    },
    startMode: {
      type: String,
      enum: ['FROM_CURRENT_EXPIRY', 'FROM_TODAY'],
      default: 'FROM_TODAY',
    },
    paymentMode: {
      type: String,
      enum: ['Cash', 'UPI', 'Bank Transfer', 'Other'],
      default: 'Cash',
    },
    paymentReference: { type: String, trim: true, maxlength: 100 },
    note: { type: String, trim: true, maxlength: 500 },
    createdByAdmin: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
  },
  { timestamps: true },
);

rechargeHistorySchema.index({ createdAt: -1 });

module.exports = mongoose.model('RechargeHistory', rechargeHistorySchema);
