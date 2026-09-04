const AuditLog = require('../models/AuditLog');
const asyncHandler = require('../utils/asyncHandler');
const { getPagination, paginationMeta } = require('../utils/pagination');
const { success } = require('../utils/response');

const listAuditLogs = asyncHandler(async (req, res) => {
  const { page, limit, skip } = getPagination(req.query);
  const filter = {};
  if (req.query.user) filter.user = req.query.user;
  if (req.query.action) filter.action = req.query.action;
  if (req.query.module) filter.module = req.query.module;
  if (req.query.from || req.query.to) {
    filter.timestamp = {};
    if (req.query.from) {
      filter.timestamp.$gte = new Date(`${req.query.from}T00:00:00.000Z`);
    }
    if (req.query.to) {
      filter.timestamp.$lte = new Date(`${req.query.to}T23:59:59.999Z`);
    }
  }
  const [logs, total] = await Promise.all([
    AuditLog.find(filter)
      .populate('user', 'fullName username email')
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(limit),
    AuditLog.countDocuments(filter),
  ]);
  return success(res, {
    data: { logs },
    pagination: paginationMeta(page, limit, total),
  });
});

module.exports = { listAuditLogs };
