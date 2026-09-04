const PrintLog = require('../models/PrintLog');

/**
 * Generates a unique print ID like PR-000091
 */
async function generatePrintId() {
  const lastLog = await PrintLog.findOne().sort({ createdAt: -1 });
  let sequence = 1;
  
  if (lastLog && lastLog.printId) {
    const parts = lastLog.printId.split('-');
    if (parts.length === 2) {
      sequence = parseInt(parts[1], 10) + 1;
    }
  }

  const sequenceStr = sequence.toString().padStart(6, '0');
  return `PR-${sequenceStr}`;
}

module.exports = { generatePrintId };
