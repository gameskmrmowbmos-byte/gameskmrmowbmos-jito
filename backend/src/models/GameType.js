const mongoose = require('mongoose');

const gameTypeSchema = new mongoose.Schema(
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
    parentType: { type: String, trim: true, maxlength: 100 },
    displayOrder: { type: Number, default: 0, index: true },
    isActive: { type: Boolean, default: true, index: true },
    validationConfig: { type: mongoose.Schema.Types.Mixed, default: {} },
    description: { type: String, trim: true, maxlength: 500 },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

gameTypeSchema.index({ name: 'text', code: 'text', parentType: 'text' });

module.exports = mongoose.model('GameType', gameTypeSchema);
