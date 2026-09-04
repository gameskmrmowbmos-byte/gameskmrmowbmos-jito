const mongoose = require('mongoose');

const stringList = {
  type: [String],
  default: [],
  set: (values) => (Array.isArray(values) ? values.map((value) => `${value}`) : []),
};

const numberSetValueSchema = new mongoose.Schema(
  {
    value: {
      type: String,
      required: true,
      trim: true,
      maxlength: 30,
    },
    ank: {
      type: String,
      trim: true,
      maxlength: 2,
    },
    pannaType: {
      type: String,
      uppercase: true,
      trim: true,
      maxlength: 10,
    },
    motor: {
      type: String,
      uppercase: true,
      trim: true,
      maxlength: 30,
    },
    column: {
      type: Number,
      min: 1,
      max: 10,
    },
  },
  { _id: false },
);

const numberSetGroupSchema = new mongoose.Schema(
  {
    ank: {
      type: String,
      trim: true,
      maxlength: 30,
    },
    label: {
      type: String,
      trim: true,
      maxlength: 100,
    },
    pannaType: {
      type: String,
      uppercase: true,
      trim: true,
      maxlength: 10,
    },
    motor: {
      type: String,
      uppercase: true,
      trim: true,
      maxlength: 30,
    },
    numbers: stringList,
    sp: stringList,
    dp: stringList,
    tp: stringList,
  },
  { _id: false },
);

const numberSetSchema = new mongoose.Schema(
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
    numberLength: {
      type: Number,
      min: 1,
      max: 20,
    },
    values: {
      type: [numberSetValueSchema],
      default: [],
    },
    groups: {
      type: [numberSetGroupSchema],
      default: [],
    },
  },
  { timestamps: true },
);

module.exports = mongoose.model('NumberSet', numberSetSchema);
