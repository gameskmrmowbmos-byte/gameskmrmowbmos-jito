const Settings = require('../models/Settings');

function isSameLocalDate(left, right) {
  return (
    left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate()
  );
}

function minutesFromTime(time) {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

async function canEditEntry({ user, market, entry, now = new Date() }) {
  if (user.role === 'admin') return { allowed: true };

  const settings = await Settings.getApplicationSettings();
  if (!settings.allowEntryEditing) {
    return { allowed: false, reason: 'Entry editing is disabled by settings' };
  }

  const entryDate = new Date(entry.entryDate);
  if (!isSameLocalDate(entryDate, now)) {
    return {
      allowed: false,
      reason: 'Operators can edit entries only on the entry date',
    };
  }

  const currentMinutes = now.getHours() * 60 + now.getMinutes();
  const cutoff =
    minutesFromTime(market.closingTime) - settings.editingCutoffMinutes;
  if (currentMinutes >= cutoff) {
    return {
      allowed: false,
      reason: 'The market editing cutoff time has passed',
    };
  }

  return { allowed: true };
}

module.exports = { canEditEntry, isSameLocalDate, minutesFromTime };

