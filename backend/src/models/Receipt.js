const mongoose = require('mongoose');

const receiptSchema = new mongoose.Schema(
  {
    receiptNumber: { type: String, required: true, unique: true, index: true },
    date: { type: Date, required: true, index: true },
    market: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Market',
      required: true,
      index: true,
    },
    session: { type: String, enum: ['Open', 'Close'], required: true },
    totalAmount: { type: Number, required: true, min: 0 },
    totalItems: { type: Number, required: true, min: 1 },
    isOtc: { type: Boolean, default: false },
    operator: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['Active', 'Cancelled'],
      default: 'Active',
      index: true,
    },
    printStatus: {
      type: String,
      enum: ['Printed', 'Not Printed'],
      default: 'Not Printed',
    },
    cancellationReason: { type: String, maxlength: 500 },
    cancelledAt: { type: Date },
    customerName: { type: String, trim: true, maxlength: 100 },
    customerMobile: { type: String, trim: true, maxlength: 20 },
    notes: { type: String, trim: true, maxlength: 1000 },
  },
  { timestamps: true },
);

receiptSchema.index({ receiptNumber: 'text' });
receiptSchema.index({ operator: 1, date: -1 });
receiptSchema.index({ operator: 1, receiptNumber: 1 });

module.exports = mongoose.model('Receipt', receiptSchema);
