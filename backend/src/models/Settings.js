const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const timePattern = /^([01]\d|2[0-3]):[0-5]\d$/;

const settingsSchema = new mongoose.Schema(
  {
    singletonKey: {
      type: String,
      default: 'application',
      unique: true,
      immutable: true,
    },

    // General Settings
    applicationName: { type: String, default: 'Matka Entry System' },
    businessName: { type: String, default: 'Matka Business' },
    address: { type: String, default: '' },
    contactNumber: { type: String, default: '' },
    alternateNumber: { type: String, default: '' },
    currency: { type: String, default: 'INR' },
    dateFormat: { type: String, default: 'DD-MM-YYYY' },
    timeFormat: { type: String, default: 'hh:mm A' },
    defaultMarket: { type: mongoose.Schema.Types.ObjectId, ref: 'Market' },
    defaultSession: { type: String, enum: ['Open', 'Close'], default: 'Open' },

    // Entry Editing
    allowEntryEditing: { type: Boolean, default: true },
    editingCutoffMinutes: { type: Number, default: 15, min: 0, max: 1440 },
    paginationSize: { type: Number, default: 20, min: 5, max: 100 },

    // Printer Settings
    printerType: { type: String, default: 'Thermal' },
    connectionType: { type: String, default: 'USB' },
    printerName: { type: String, default: '' },
    paperSize: { type: String, enum: ['58mm', '80mm'], default: '58mm' },
    defaultCopies: { type: Number, default: 1, min: 1, max: 10 },
    autoCut: { type: Boolean, default: false },
    printLogo: { type: Boolean, default: false },

    // Receipt Settings
    receiptHeading: { type: String, default: 'Welcome' },
    footerMessage: { type: String, default: 'Thank You' },
    showCustomerName: { type: Boolean, default: true },
    showCustomerMobile: { type: Boolean, default: true },
    showQrCode: { type: Boolean, default: true },
    showPrintId: { type: Boolean, default: true },
    showOperatorName: { type: Boolean, default: true },
    showJackpotSymbol: { type: Boolean, default: true },
    showMarketSession: { type: Boolean, default: true },
    requirePreviewBeforePrint: { type: Boolean, default: true },

    // Security Settings
    adminPin: { type: String, select: false },
    adminPinHash: { type: String, select: false },
    allowReprint: { type: Boolean, default: true },
    requirePinForReprint: { type: Boolean, default: true },
    requirePinForCancellation: { type: Boolean, default: true },
    confirmBeforeCancellation: { type: Boolean, default: true },
    confirmBeforeReprint: { type: Boolean, default: true },
    auditLoggingEnabled: { type: Boolean, default: true },
    sessionTimeoutMinutes: { type: Number, default: 60, min: 5, max: 1440 },
    singleDeviceLoginEnabled: { type: Boolean, default: false },

    // Data Retention
    retentionPeriodDays: { type: Number, default: 30, min: 1 },
    automaticDeletion: { type: Boolean, default: false },
    exportBeforeDeletion: { type: Boolean, default: true },
    cleanupSchedule: { type: String, default: '23:45', match: timePattern },
    lastCleanupAt: { type: Date },
    lastCleanupStatus: { type: String },

    // Backup
    autoBackup: { type: Boolean, default: false },
    backupTime: { type: String, default: '23:30', match: timePattern },
    backupType: { type: String, default: 'json' },
    backupLocation: { type: String, default: 'Local System' },
    lastBackupAt: { type: Date },
    lastBackupStatus: { type: String },

    // Other Settings
    soundEnabled: { type: Boolean, default: false },
    vibrationEnabled: { type: Boolean, default: true },
    previewBeforeSave: { type: Boolean, default: true },
    confirmBeforeSave: { type: Boolean, default: true },
    confirmBeforeClear: { type: Boolean, default: true },

    // Admin / subscription settings
    subscriptionWarningDays: { type: Number, default: 3, min: 1, max: 60 },
    allowNewRegistrations: { type: Boolean, default: true },
    requireManualApproval: { type: Boolean, default: true },
    defaultApprovalStatus: {
      type: String,
      enum: ['PENDING', 'APPROVED'],
      default: 'PENDING',
    },
    supportMobileNumber: { type: String, default: '', maxlength: 20 },
    supportWhatsAppNumber: { type: String, default: '', maxlength: 20 },

    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

settingsSchema.methods.setAdminPin = async function setAdminPin(pin) {
  this.adminPinHash = await bcrypt.hash(pin, 12);
  this.adminPin = undefined;
};

settingsSchema.methods.verifyAdminPin = async function verifyAdminPin(pin) {
  if (!this.adminPinHash) return pin === '1234';
  return bcrypt.compare(pin, this.adminPinHash);
};

settingsSchema.methods.toSafeObject = function toSafeObject() {
  const value = this.toObject();
  delete value.adminPin;
  delete value.adminPinHash;
  return value;
};

settingsSchema.statics.getApplicationSettings = async function getApplicationSettings() {
  const settings = await this.findOneAndUpdate(
    { singletonKey: 'application' },
    { $setOnInsert: { singletonKey: 'application' } },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  ).select('+adminPin +adminPinHash');

  if (!settings.adminPinHash) {
    await settings.setAdminPin(settings.adminPin || '1234');
    await settings.save();
  }

  return settings;
};

module.exports = mongoose.model('Settings', settingsSchema);
