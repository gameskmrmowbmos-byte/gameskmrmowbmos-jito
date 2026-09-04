const mongoose = require('mongoose');

const printLogSchema = new mongoose.Schema(
  {
    printId: { type: String, required: true, unique: true, index: true },
    receipt: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Receipt',
      required: true,
      index: true,
    },
    printType: {
      type: String,
      enum: ['Original', 'Duplicate'],
      required: true,
    },
    printNumber: { type: Number, min: 1 },
    printerName: { type: String, required: true, trim: true },
    printerType: { type: String, trim: true, maxlength: 50 },
    paperSize: { type: String, trim: true, maxlength: 20 },
    deviceId: { type: String, trim: true, maxlength: 100 },
    operator: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['Success', 'Failed', 'Pending'],
      default: 'Pending',
    },
    errorMessage: { type: String, trim: true, maxlength: 1000 },
    reprintReason: { type: String, trim: true, maxlength: 500 },
    retryReason: { type: String, trim: true, maxlength: 500 },
    printedAt: { type: Date, required: true },
  },
  { timestamps: true },
);

printLogSchema.index({ printId: 'text' });
printLogSchema.index({ operator: 1, createdAt: -1 });

module.exports = mongoose.model('PrintLog', printLogSchema);
