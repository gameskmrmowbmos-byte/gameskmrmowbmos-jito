const mongoose = require('mongoose');
const { STANDARD_GAME_CONFIG_CODE } = require('../constants/gameConfig.constants');

const timePattern = /^([01]\d|2[0-3]):[0-5]\d$/;

const marketSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 100 },
    code: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      uppercase: true,
      maxlength: 20,
    },
    openingTime: { type: String, default: '00:00', match: timePattern },
    closingTime: { type: String, default: '23:59', match: timePattern },
    resultTime: { type: String, required: true, match: timePattern },
    isActive: { type: Boolean, default: true, index: true },
    gameConfigCode: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
      maxlength: 50,
      default: STANDARD_GAME_CONFIG_CODE,
    },
    description: { type: String, trim: true, maxlength: 500 },
    displayOrder: { type: Number, default: 0, index: true },
    isDeleted: { type: Boolean, default: false, index: true },
    deletedAt: Date,
    deletedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  { timestamps: true },
);

marketSchema.index({ name: 'text', code: 'text' });
marketSchema.index({ displayOrder: 1, createdAt: 1 });

module.exports = mongoose.model('Market', marketSchema);

