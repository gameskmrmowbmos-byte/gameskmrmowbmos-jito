const mongoose = require('mongoose');

const stringList = {
  type: [String],
  default: [],
  set: (values) => (Array.isArray(values) ? values.map((value) => `${value}`) : []),
};

const betTypeSchema = new mongoose.Schema(
  {
    enabled: { type: Boolean, default: false },
    values: stringList,
    allowedLength: { type: Number, min: 1, max: 30 },
    backendType: { type: String, trim: true, maxlength: 50 },
    missingRule: { type: String, trim: true, maxlength: 300 },
    rules: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { _id: false },
);

const pannaSubtypeSchema = new mongoose.Schema(
  {
    enabled: { type: Boolean, default: false },
    allowedNumbers: stringList,
    missingRule: { type: String, trim: true, maxlength: 300 },
    rules: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { _id: false },
);

const gameConfigSchema = new mongoose.Schema(
  {
    code: {
      type: String,
      required: true,
      unique: true,
      uppercase: true,
      trim: true,
      maxlength: 50,
    },
    label: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    isActive: { type: Boolean, default: true, index: true },
    single: { type: betTypeSchema, default: () => ({}) },
    jodi: { type: betTypeSchema, default: () => ({}) },
    panna: {
      enabled: { type: Boolean, default: false },
      masterNumberSetCode: { type: String, uppercase: true, trim: true },
      backendType: { type: String, default: 'Patti', trim: true },
      subtypes: {
        pana: { type: pannaSubtypeSchema, default: () => ({}) },
        sp: { type: pannaSubtypeSchema, default: () => ({}) },
        dp: { type: pannaSubtypeSchema, default: () => ({}) },
        tp: { type: pannaSubtypeSchema, default: () => ({}) },
      },
    },
    halfSangam: { type: betTypeSchema, default: () => ({}) },
    fullSangam: { type: betTypeSchema, default: () => ({}) },
  },
  { timestamps: true },
);

module.exports = mongoose.model('GameConfig', gameConfigSchema);
