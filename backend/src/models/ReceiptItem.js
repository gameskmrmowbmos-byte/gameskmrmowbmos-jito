const mongoose = require('mongoose');

const receiptItemSchema = new mongoose.Schema(
  {
    receipt: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Receipt',
      required: true,
      index: true,
    },
    type: {
      type: String,
      required: true,
      trim: true,
      maxlength: 50,
    },
    number: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    amount: {
      type: Number,
      required: true,
      min: 0.01,
    },
    mode: {
      type: String,
      enum: ['Manual', 'Auto'],
      default: 'Manual',
      index: true,
    },
    betType: {
      type: String,
      uppercase: true,
      trim: true,
      maxlength: 50,
    },
    betSubtype: {
      type: String,
      uppercase: true,
      trim: true,
      maxlength: 50,
    },
    sessionOverride: {
      type: String,
      enum: ['Close'],
      default: undefined,
    },
    isJackpot: {
      type: Boolean,
      default: false,
    },
    components: {
      type: mongoose.Schema.Types.Mixed,
      default: undefined,
    },
  },
  { timestamps: true },
);

module.exports = mongoose.model('ReceiptItem', receiptItemSchema);
