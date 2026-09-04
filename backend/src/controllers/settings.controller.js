const mongoose = require('mongoose');
const Market = require('../models/Market');
const PrintLog = require('../models/PrintLog');
const Receipt = require('../models/Receipt');
const ReceiptItem = require('../models/ReceiptItem');
const Settings = require('../models/Settings');
const User = require('../models/User');
const { recordAudit } = require('../services/audit.service');
const { runJsonBackup } = require('../services/backup.service');
const { runRetentionCleanup } = require('../services/cleanup.service');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { success } = require('../utils/response');

const sectionFields = {
  general: [
    'applicationName',
    'businessName',
    'address',
    'contactNumber',
    'alternateNumber',
    'currency',
    'dateFormat',
    'timeFormat',
    'paperSize',
    'defaultCopies',
    'defaultMarket',
    'defaultSession',
  ],
  printing: [
    'printerName',
    'printerType',
    'connectionType',
    'paperSize',
    'defaultCopies',
    'autoCut',
    'printLogo',
    'receiptHeading',
    'footerMessage',
    'showQrCode',
    'showOperatorName',
    'showPrintId',
    'showCustomerName',
    'showCustomerMobile',
    'showJackpotSymbol',
    'showMarketSession',
    'requirePreviewBeforePrint',
  ],
  security: [
    'allowReprint',
    'requirePinForReprint',
    'requirePinForCancellation',
    'confirmBeforeCancellation',
    'confirmBeforeReprint',
    'auditLoggingEnabled',
    'sessionTimeoutMinutes',
  ],
  retention: [
    'automaticDeletion',
    'retentionPeriodDays',
    'exportBeforeDeletion',
    'cleanupSchedule',
  ],
  backup: ['autoBackup', 'backupTime', 'backupType', 'backupLocation'],
  other: [
    'soundEnabled',
    'vibrationEnabled',
    'previewBeforeSave',
    'confirmBeforeSave',
    'confirmBeforeClear',
    'allowEntryEditing',
    'editingCutoffMinutes',
    'paginationSize',
  ],
};

const getSettings = asyncHandler(async (_req, res) => {
  const settings = await Settings.getApplicationSettings();
  return success(res, { data: { settings: settings.toSafeObject() } });
});

function applyFields(settings, body, fields) {
  for (const field of fields) {
    if (body[field] !== undefined) settings[field] = body[field];
  }
}

async function saveSection(req, section) {
  const settings = await Settings.getApplicationSettings();
  const previousValue = settings.toSafeObject();
  applyFields(settings, req.body, sectionFields[section]);
  settings.updatedBy = req.user._id;
  await settings.save();
  await recordAudit({
    req,
    user: req.user,
    action: `settings_${section}_update`,
    module: 'settings',
    recordId: settings._id,
    previousValue,
    newValue: settings.toSafeObject(),
  });
  return settings;
}

const updateSettings = asyncHandler(async (req, res) => {
  const settings = await Settings.getApplicationSettings();
  const previousValue = settings.toSafeObject();
  applyFields(settings, req.body, Object.values(sectionFields).flat());
  settings.updatedBy = req.user._id;
  await settings.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'settings_update',
    module: 'settings',
    recordId: settings._id,
    previousValue,
    newValue: settings.toSafeObject(),
  });
  return success(res, {
    message: 'Application settings updated',
    data: { settings: settings.toSafeObject() },
  });
});

const updateSection = (section) =>
  asyncHandler(async (req, res) => {
    const settings = await saveSection(req, section);
    return success(res, {
      message: `${section} settings updated`,
      data: { settings: settings.toSafeObject() },
    });
  });

const verifyAdminPin = asyncHandler(async (req, res) => {
  const { pin } = req.body;
  if (!pin) throw ApiError.badRequest('Admin PIN is required');
  const settings = await Settings.getApplicationSettings();
  const valid = await settings.verifyAdminPin(pin);
  if (!valid) throw ApiError.forbidden('Invalid admin PIN');
  return success(res, { data: { valid: true } });
});

const changeAdminPin = asyncHandler(async (req, res) => {
  const { currentPin, newPin } = req.body;
  if (!currentPin || !newPin) {
    throw ApiError.badRequest('Current PIN and new PIN are required');
  }
  if (`${newPin}`.length < 4 || `${newPin}`.length > 12) {
    throw ApiError.badRequest('New PIN must be 4 to 12 digits');
  }
  const settings = await Settings.getApplicationSettings();
  const valid = await settings.verifyAdminPin(currentPin);
  if (!valid) throw ApiError.forbidden('Invalid current admin PIN');
  await settings.setAdminPin(newPin);
  settings.updatedBy = req.user._id;
  await settings.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'admin_pin_changed',
    module: 'settings',
    recordId: settings._id,
  });
  return success(res, { message: 'Admin PIN changed' });
});

const databaseHealth = asyncHandler(async (_req, res) => {
  const [receipts, receiptItems, printLogs, markets, users, settings] =
    await Promise.all([
      Receipt.countDocuments(),
      ReceiptItem.countDocuments(),
      PrintLog.countDocuments(),
      Market.countDocuments(),
      User.countDocuments(),
      Settings.getApplicationSettings(),
    ]);

  const states = ['disconnected', 'connected', 'connecting', 'disconnecting'];
  return success(res, {
    data: {
      connected: mongoose.connection.readyState === 1,
      databaseName: mongoose.connection.name,
      state: states[mongoose.connection.readyState] || 'unknown',
      lastChecked: new Date(),
      lastBackupAt: settings.lastBackupAt,
      lastBackupStatus: settings.lastBackupStatus,
      lastCleanupAt: settings.lastCleanupAt,
      lastCleanupStatus: settings.lastCleanupStatus,
      counts: {
        receipts,
        receiptItems,
        printLogs,
        markets,
        users,
      },
    },
  });
});

const runBackup = asyncHandler(async (req, res) => {
  const result = await runJsonBackup();
  const settings = await Settings.getApplicationSettings();
  settings.lastBackupAt = new Date();
  settings.lastBackupStatus = 'Success';
  await settings.save();
  await recordAudit({
    req,
    user: req.user,
    action: 'manual_backup',
    module: 'settings',
    recordId: settings._id,
    metadata: { counts: result.counts },
  });
  return success(res, { message: 'Backup created', data: { backup: result } });
});

const runCleanup = asyncHandler(async (req, res) => {
  const result = await runRetentionCleanup({ force: true });
  await recordAudit({
    req,
    user: req.user,
    action: 'manual_cleanup',
    module: 'settings',
    metadata: result,
  });
  return success(res, { message: 'Cleanup completed', data: { cleanup: result } });
});

module.exports = {
  getSettings,
  updateSettings,
  updateGeneral: updateSection('general'),
  updatePrinting: updateSection('printing'),
  updateSecurity: updateSection('security'),
  updateRetention: updateSection('retention'),
  updateBackup: updateSection('backup'),
  updateOther: updateSection('other'),
  verifyAdminPin,
  changeAdminPin,
  databaseHealth,
  runBackup,
  runCleanup,
};
