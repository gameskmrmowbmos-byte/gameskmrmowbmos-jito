const Receipt = require('../models/Receipt');
const env = require('../config/env');
const zonedDatePartsFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: env.receiptTimezone,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});
const zonedMidnightFormatter = new Intl.DateTimeFormat('en-US', {
  timeZone: env.receiptTimezone,
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
  hour: 'numeric',
  minute: 'numeric',
  second: 'numeric',
  hourCycle: 'h23',
});

function numericDateParts(parts) {
  const values = {};
  for (const { type, value } of parts) {
    if (type !== 'literal') values[type] = Number(value);
  }
  return values;
}

function zonedDateParts(date) {
  const parts = zonedDatePartsFormatter.formatToParts(date);
  return numericDateParts(parts);
}

function zonedMidnightUtc(year, month, day) {
  const approximate = new Date(Date.UTC(year, month - 1, day));
  const parts = zonedMidnightFormatter.formatToParts(approximate);
  const values = numericDateParts(parts);
  const observed = Date.UTC(
    values.year,
    values.month - 1,
    values.day,
    values.hour,
    values.minute,
    values.second,
  );
  return new Date(approximate.getTime() - (observed - approximate.getTime()));
}

/**
 * Generates a unique receipt number like RC-20260803-0012
 */
async function generateReceiptNumber() {
  const now = new Date();
  const { year, month, day } = zonedDateParts(now);
  const dateStr = `${year}${String(month).padStart(2, '0')}${String(day).padStart(2, '0')}`;
  const todayStart = zonedMidnightUtc(year, month, day);
  const tomorrowStart = zonedMidnightUtc(
    new Date(Date.UTC(year, month - 1, day + 1)).getUTCFullYear(),
    new Date(Date.UTC(year, month - 1, day + 1)).getUTCMonth() + 1,
    new Date(Date.UTC(year, month - 1, day + 1)).getUTCDate(),
  );

  const lastReceipt = await Receipt.findOne({
    date: { $gte: todayStart, $lt: tomorrowStart },
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
