const Receipt = require('../models/Receipt');

/**
 * Generates a unique receipt number like RC-20260803-0012
 */
async function generateReceiptNumber() {
  const dateStr = new Date().toISOString().split('T')[0].replace(/-/g, ''); // YYYYMMDD
  
  // Find the latest receipt for today to determine the sequence number
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date();
  todayEnd.setHours(23, 59, 59, 999);

  const lastReceipt = await Receipt.findOne({
    date: { $gte: todayStart, $lte: todayEnd }
  }).sort({ createdAt: -1 });

  let sequence = 1;
  if (lastReceipt && lastReceipt.receiptNumber) {
    const parts = lastReceipt.receiptNumber.split('-');
    if (parts.length === 3) {
      sequence = parseInt(parts[2], 10) + 1;
    }
  }

  const sequenceStr = sequence.toString().padStart(4, '0');
  return `RC-${dateStr}-${sequenceStr}`;
}

module.exports = { generateReceiptNumber };
