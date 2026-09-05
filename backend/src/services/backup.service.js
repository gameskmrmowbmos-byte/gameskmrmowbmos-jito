const fs = require('fs/promises');
const os = require('os');
const path = require('path');
const Market = require('../models/Market');
const PrintLog = require('../models/PrintLog');
const Receipt = require('../models/Receipt');
const ReceiptItem = require('../models/ReceiptItem');
const Settings = require('../models/Settings');
const User = require('../models/User');

async function runJsonBackup() {
  const backupDir = path.join(os.tmpdir(), 'matka-management-backups');
  await fs.mkdir(backupDir, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const filePath = path.join(backupDir, `backup-${timestamp}.json`);

  const [receipts, receiptItems, printLogs, markets, users, settings] =
    await Promise.all([
      Receipt.find().lean(),
      ReceiptItem.find().lean(),
      PrintLog.find().lean(),
      Market.find().lean(),
      User.find().select('-passwordHash -refreshTokenHash -loginHistory').lean(),
      Settings.find().select('-adminPin -adminPinHash').lean(),
    ]);

  await fs.writeFile(
    filePath,
    JSON.stringify(
      {
        createdAt: new Date().toISOString(),
        receipts,
        receiptItems,
        printLogs,
        markets,
        users,
        settings,
      },
      null,
      2,
    ),
  );

  return {
    filePath,
    counts: {
      receipts: receipts.length,
      receiptItems: receiptItems.length,
      printLogs: printLogs.length,
      markets: markets.length,
      users: users.length,
    },
  };
}

module.exports = { runJsonBackup };
