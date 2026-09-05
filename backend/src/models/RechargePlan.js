const mongoose = require('mongoose');

const rechargePlanSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 100 },
    code: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      uppercase: true,
      maxlength: 40,
    },
    validityDays: { type: Number, required: true, min: 1, max: 3650 },
    price: { type: Number, required: true, min: 0 },
    description: { type: String, trim: true, maxlength: 500 },
    isActive: { type: Boolean, default: true, index: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

rechargePlanSchema.index({ name: 'text', code: 'text' });

module.exports = mongoose.model('RechargePlan', rechargePlanSchema);
