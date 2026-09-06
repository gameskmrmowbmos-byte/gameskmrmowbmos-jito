const mongoose = require('mongoose');
const Receipt = require('../models/Receipt');
const ReceiptItem = require('../models/ReceiptItem');
const PrintLog = require('../models/PrintLog');
const { recordAudit } = require('../services/audit.service');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { getPagination, paginationMeta } = require('../utils/pagination');
const { success } = require('../utils/response');
const { generateReceiptNumber } = require('../utils/receiptNumber');
const { validateReceiptPayload } = require('../services/gameConfig.service');

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function dayRange(fromDate, toDate) {
  const from = new Date(fromDate);
  const to = new Date(toDate);
  to.setHours(23, 59, 59, 999);
  return mongoose.trusted({ $gte: from, $lte: to });
}

function receiptScope(req, extra = {}) {
  if (req.user.role === 'admin') return extra;
  return { ...extra, operator: req.user._id };
}

function truthyFlag(value) {
  if (value === true) return true;
  const text = `${value || ''}`.trim().toLowerCase();
  return text === 'true' || text === '1' || text === 'yes' || text === 'bz';
}

function receiptItemHasBazar(item) {
  const components =
    item.components && typeof item.components === 'object' && !Array.isArray(item.components)
      ? item.components
      : {};
  return (
    truthyFlag(components.bazar) ||
    truthyFlag(components.bazarSangam) ||
    truthyFlag(components.isBazar)
  );
}

const listReceipts = asyncHandler(async (req, res) => {
  const { page, limit, skip } = getPagination(req.query, 50);
  const filter = receiptScope(req);
  
  if (req.query.status) filter.status = req.query.status;
  if (req.query.printStatus) filter.printStatus = req.query.printStatus;
  if (req.query.market) filter.market = req.query.market;
  if (req.query.session) filter.session = req.query.session;
  if (req.query.customerMobile) {
    filter.customerMobile = {
      $regex: escapeRegex(req.query.customerMobile),
      $options: 'i',
    };
  }
  if (req.query.receiptNumber) {
    filter.receiptNumber = {
      $regex: escapeRegex(req.query.receiptNumber),
      $options: 'i',
    };
  }
  
  if (req.query.fromDate && req.query.toDate) {
    filter.date = dayRange(req.query.fromDate, req.query.toDate);
  }

  if (req.query.number) {
    const matchingItems = await ReceiptItem.distinct('receipt', {
      number: {
        $regex: escapeRegex(req.query.number),
        $options: 'i',
      },
    });
    filter._id = { $in: matchingItems };
  }

  if (req.query.search) {
    const escaped = escapeRegex(req.query.search);
    filter.receiptNumber = { $regex: escaped, $options: 'i' };
  }

  const [receipts, total] = await Promise.all([
    Receipt.find(filter)
      .populate('market', 'name code')
      .populate('operator', 'fullName username')
      .sort({ date: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Receipt.countDocuments(filter),
  ]);

  return success(res, {
    data: { receipts },
    pagination: paginationMeta(page, limit, total),
  });
});

const getReceipt = asyncHandler(async (req, res) => {
  const receipt = await Receipt.findOne(receiptScope(req, { _id: req.params.id }))
    .populate('market', 'name code')
    .populate('operator', 'fullName username');

  if (!receipt) throw ApiError.notFound('Receipt not found');
  if (req.user.role !== 'admin' && receipt.operator._id.toString() !== req.user._id.toString()) {
    throw ApiError.forbidden('Access denied');
  }

  const [items, printLogs] = await Promise.all([
    ReceiptItem.find({ receipt: receipt._id }),
    PrintLog.find({ receipt: receipt._id }).sort({ createdAt: -1 }),
  ]);

  return success(res, {
    data: {
      receipt,
      items,
      printLogs,
    },
  });
});

const searchReceipt = asyncHandler(async (req, res) => {
  const { query, method = 'receiptNumber' } = req.query;
  if (!query) throw ApiError.badRequest('Search query is required');

  const escaped = escapeRegex(query.trim());
  const filter =
    method === 'mobile'
      ? { customerMobile: { $regex: escaped, $options: 'i' } }
      : { receiptNumber: { $regex: `^${escaped}$`, $options: 'i' } };
  Object.assign(filter, receiptScope(req));

  const receipt = await Receipt.findOne(filter)
    .populate('market', 'name code')
    .populate('operator', 'fullName username');
    
  if (!receipt) throw ApiError.notFound('Receipt not found');

  const [items, printLogs] = await Promise.all([
    ReceiptItem.find({ receipt: receipt._id }),
    PrintLog.find({ receipt: receipt._id }).sort({ createdAt: -1 }),
  ]);

  return success(res, {
    data: {
      receipt,
      items,
      printLogs,
    },
  });
});

const createReceipt = asyncHandler(async (req, res) => {
  const { market, session, items, customerName, customerMobile, notes } = req.body;
  const isOtc = req.body.isOtc === true;
  const validated = await validateReceiptPayload({
    marketId: market,
    session,
    items,
    user: req.user,
  });

  if (isOtc && validated.items.some(receiptItemHasBazar)) {
    throw ApiError.badRequest('OTC is not allowed with Bazar entries');
  }
  if (isOtc && validated.session === 'Close') {
    throw ApiError.badRequest('OTC is not allowed in Close session');
  }

  const baseTotalAmount = validated.items.reduce((sum, item) => sum + item.amount, 0);
  const totalAmount = isOtc ? baseTotalAmount * 2 : baseTotalAmount;
  const totalItems = validated.items.length;

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const sessionDB = await mongoose.startSession();
    sessionDB.startTransaction();
    let committed = false;

    try {
      const receiptNumber = await generateReceiptNumber();

      const receipt = new Receipt({
        receiptNumber,
        date: new Date(),
        market: validated.market._id,
        session: validated.session,
        totalAmount,
        totalItems,
        isOtc,
        operator: req.user._id,
        customerName,
        customerMobile,
        notes,
      });

      await receipt.save({ session: sessionDB });

      const receiptItemsToInsert = validated.items.map(item => ({
        receipt: receipt._id,
        type: item.type,
        number: item.number?.toString(),
        amount: item.amount,
        mode: item.mode,
        betType: item.betType,
        betSubtype: item.betSubtype,
        sessionOverride: item.sessionOverride,
        isJackpot: item.isJackpot,
        components: item.components,
      }));

      const receiptItems = await ReceiptItem.insertMany(receiptItemsToInsert, {
        session: sessionDB,
      });

      await sessionDB.commitTransaction();
      committed = true;
      sessionDB.endSession();

      const populatedReceipt = await Receipt.findById(receipt._id)
        .populate('market', 'name code')
        .populate('operator', 'fullName username');

      return success(res, {
        statusCode: 201,
        message: 'Receipt created successfully',
        data: { receipt: populatedReceipt, items: receiptItems },
      });
    } catch (error) {
      if (!committed) await sessionDB.abortTransaction();
      sessionDB.endSession();
      if (committed || error?.code !== 11000 || attempt === 2) throw error;
    }
  }
});

const cancelReceipt = asyncHandler(async (req, res) => {
  const { reason, adminPin } = req.body; // Logic for PIN check would go here if not handled by middleware
  
  if (!reason) throw ApiError.badRequest('Cancellation reason is required');

  const receipt = await Receipt.findById(req.params.id);
  if (!receipt) throw ApiError.notFound('Receipt not found');
  if (receipt.status === 'Cancelled') throw ApiError.badRequest('Receipt is already cancelled');

  receipt.status = 'Cancelled';
  receipt.cancellationReason = reason;
  receipt.cancelledAt = new Date();
  
  await receipt.save();

  await recordAudit({
    req,
    user: req.user,
    action: 'receipt_cancellation',
    module: 'receipts',
    recordId: receipt._id,
    newValue: { status: 'Cancelled', reason },
  });

  return success(res, {
    message: 'Receipt cancelled successfully',
    data: { receipt },
  });
});

module.exports = {
  listReceipts,
  getReceipt,
  searchReceipt,
  createReceipt,
  cancelReceipt,
};
