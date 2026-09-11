const PrintLog = require('../models/PrintLog');
const Receipt = require('../models/Receipt');
const ReceiptItem = require('../models/ReceiptItem');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { getPagination, paginationMeta } = require('../utils/pagination');
const { success } = require('../utils/response');
const { generatePrintId } = require('../utils/printId');
const { recordAudit } = require('../services/audit.service');

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function printedAtRange(fromDate, toDate) {
  const from = new Date(fromDate);
  const to = new Date(toDate);
  to.setHours(23, 59, 59, 999);
  return { $gte: from, $lte: to };
}

async function receiptIdsForQuery(query, user) {
  const receiptFilter = user.role === 'admin' ? {} : { operator: user._id };
  if (query.market) receiptFilter.market = query.market;
  if (query.session) receiptFilter.session = query.session;
  if (query.receiptNumber) {
    receiptFilter.receiptNumber = {
      $regex: escapeRegex(query.receiptNumber),
      $options: 'i',
    };
  }
  if (Object.keys(receiptFilter).length === 0) return null;
  return Receipt.distinct('_id', receiptFilter);
}

async function hydratePrintDetail(printLog) {
  const receiptId = printLog.receipt?._id ?? printLog.receipt;
  const [items, printLogs] = await Promise.all([
    ReceiptItem.find({ receipt: receiptId }),
    PrintLog.find({ receipt: receiptId })
      .populate('operator', 'fullName username')
      .sort({ createdAt: -1 }),
  ]);
  const reprintCount = printLogs.filter(
    (log) => log.printType === 'Duplicate' && log.status === 'Success',
  ).length;
  const receipt =
    typeof printLog.receipt?.toObject === 'function'
      ? printLog.receipt.toObject()
      : printLog.receipt;
  return {
    printLog,
    receipt: { ...receipt, reprintCount },
    items,
    printLogs,
    matchedPrintLog: printLog,
  };
}

const listPrintLogs = asyncHandler(async (req, res) => {
  const { page, limit, skip } = getPagination(req.query, 50);
  const filter = req.user.role === 'admin' ? {} : { operator: req.user._id };
  
  if (req.query.printType) filter.printType = req.query.printType;
  if (req.query.status) filter.status = req.query.status;
  if (req.query.receipt) filter.receipt = req.query.receipt;
  if (req.query.operator && req.user.role === 'admin') filter.operator = req.query.operator;
  if (req.query.printerName) {
    filter.printerName = {
      $regex: escapeRegex(req.query.printerName),
      $options: 'i',
    };
  }
  if (req.query.printId) {
    filter.printId = {
      $regex: escapeRegex(req.query.printId),
      $options: 'i',
    };
  }
  
  if (req.query.fromDate && req.query.toDate) {
    filter.printedAt = printedAtRange(req.query.fromDate, req.query.toDate);
  }

  const receiptIds = await receiptIdsForQuery(req.query, req.user);
  if (receiptIds) {
    filter.receipt = filter.receipt
      ? filter.receipt
      : { $in: receiptIds };
  }

  const [logs, total] = await Promise.all([
    PrintLog.find(filter)
      .populate({
        path: 'receipt',
        populate: [
          { path: 'market', select: 'name code' },
          { path: 'operator', select: 'fullName username' },
        ],
      })
      .populate('operator', 'fullName username')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    PrintLog.countDocuments(filter),
  ]);

  return success(res, {
    data: { logs },
    pagination: paginationMeta(page, limit, total),
  });
});

const createPrintLog = asyncHandler(async (req, res) => {
  const {
    receiptId,
    printType,
    printerName,
    printerType,
    paperSize,
    deviceId,
    status,
    errorMessage,
    reprintReason,
    retryReason,
  } = req.body;
  
  if (!receiptId || !printType || !printerName) {
    throw ApiError.badRequest('receiptId, printType, and printerName are required');
  }

  const receipt = await Receipt.findById(receiptId);
  if (!receipt) throw ApiError.notFound('Receipt not found');
  if (req.user.role !== 'admin' && receipt.operator.toString() !== req.user._id.toString()) {
    throw ApiError.forbidden('Access denied');
  }
  if (receipt.status === 'Cancelled') {
    throw ApiError.badRequest('Cancelled receipts cannot be reprinted');
  }
  if (printType === 'Duplicate' && !reprintReason) {
    throw ApiError.badRequest('Reprint reason is required');
  }

  if (printType === 'Original') {
    const existingOriginal = await PrintLog.exists({
      receipt: receiptId,
      printType: 'Original',
      status: 'Success',
    });
    if (existingOriginal) {
      throw ApiError.conflict('A successful original print already exists');
    }
  }

  const printId = await generatePrintId();
  const printNumber = (await PrintLog.countDocuments({ receipt: receiptId })) + 1;

  const printLog = await PrintLog.create({
    printId,
    receipt: receiptId,
    printType,
    printNumber,
    printerName,
    printerType,
    paperSize,
    deviceId,
    operator: req.user._id,
    status: status || 'Success',
    errorMessage,
    reprintReason,
    retryReason,
    printedAt: new Date(),
  });

  // Reprints are stored as print logs only; they must not touch receipt dates.
  if (printLog.status === 'Success' && printType === 'Original') {
    receipt.printStatus = 'Printed';
    await receipt.save();
  }

  if (printType === 'Duplicate') {
    await recordAudit({
      req,
      user: req.user,
      action: 'receipt_reprint',
      module: 'prints',
      recordId: receipt._id,
      newValue: { printId, reason: reprintReason },
    });
  }

  return success(res, {
    statusCode: 201,
    message: 'Print log created successfully',
    data: { printLog },
  });
});

const getPrintLog = asyncHandler(async (req, res) => {
  const printLog = await PrintLog.findById(req.params.id)
    .populate({
      path: 'receipt',
      populate: [
        { path: 'market', select: 'name code' },
        { path: 'operator', select: 'fullName username' },
      ],
    })
    .populate('operator', 'fullName username');

  if (!printLog) throw ApiError.notFound('Print log not found');
  if (req.user.role !== 'admin' && printLog.operator._id.toString() !== req.user._id.toString()) {
    throw ApiError.forbidden('Access denied');
  }
  return success(res, { data: await hydratePrintDetail(printLog) });
});

const findByPrintId = asyncHandler(async (req, res) => {
  const { printId } = req.query;
  if (!printId) throw ApiError.badRequest('Print ID is required');

  const escaped = printId.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const printLog = await PrintLog.findOne({
    printId: { $regex: `^${escaped}$`, $options: 'i' },
    ...(req.user.role === 'admin' ? {} : { operator: req.user._id }),
  })
    .populate({
      path: 'receipt',
      populate: [
        { path: 'market', select: 'name code' },
        { path: 'operator', select: 'fullName username' },
      ],
    })
    .populate('operator', 'fullName username');

  if (!printLog) throw ApiError.notFound('Print log not found');

  return success(res, { data: await hydratePrintDetail(printLog) });
});

module.exports = {
  listPrintLogs,
  createPrintLog,
  getPrintLog,
  findByPrintId,
};
