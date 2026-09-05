const AuditLog = require('../models/AuditLog');
const logger = require('../utils/logger');

async function recordAudit({
  req,
  user,
  action,
  module,
  recordId,
  previousValue,
  newValue,
  metadata,
}) {
  try {
    return await AuditLog.create({
      user: user?._id || user || undefined,
      action,
      module,
      recordId,
      previousValue,
      newValue,
      metadata,
      ipAddress: req?.ip,
      userAgent: req?.get?.('user-agent'),
    });
  } catch (error) {
    logger.error('Audit log creation failed', {
      action,
      module,
      error: error.message,
    });
    return null;
  }
}

module.exports = { recordAudit };

