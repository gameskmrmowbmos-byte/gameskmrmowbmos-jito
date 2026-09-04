const PrintLog = require('../models/PrintLog');
const Receipt = require('../models/Receipt');
const ReceiptItem = require('../models/ReceiptItem');
const Settings = require('../models/Settings');
const { runJsonBackup } = require('./backup.service');

async function runRetentionCleanup({ force = false } = {}) {
  const settings = await Settings.getApplicationSettings();
  if (!force && !settings.automaticDeletion) {
    return {
      skipped: true,
      reason: 'Retention cleanup is disabled',
      receiptsDeleted: 0,
      itemsDeleted: 0,
      printLogsDeleted: 0,
    };
  }

  const days = Math.max(1, Number(settings.retentionPeriodDays) || 30);
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);

  let backup;
  if (settings.exportBeforeDeletion) {
    backup = await runJsonBackup();
  }

  const receiptIds = await Receipt.distinct('_id', { date: { $lt: cutoff } });
  if (receiptIds.length === 0) {
    settings.lastCleanupAt = new Date();
    settings.lastCleanupStatus = 'No expired records';
    await settings.save();
    return {
      skipped: false,
      cutoff,
      backup,
      receiptsDeleted: 0,
      itemsDeleted: 0,
      printLogsDeleted: 0,
    };
  }

  const [items, printLogs, receipts] = await Promise.all([
    ReceiptItem.deleteMany({ receipt: { $in: receiptIds } }),
    PrintLog.deleteMany({ receipt: { $in: receiptIds } }),
    Receipt.deleteMany({ _id: { $in: receiptIds } }),
  ]);

  settings.lastCleanupAt = new Date();
  settings.lastCleanupStatus = `Deleted ${receipts.deletedCount} receipt(s)`;
  await settings.save();

  return {
    skipped: false,
    cutoff,
    backup,
    receiptsDeleted: receipts.deletedCount,
    itemsDeleted: items.deletedCount,
    printLogsDeleted: printLogs.deletedCount,
  };
}

module.exports = { runRetentionCleanup };
