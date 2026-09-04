const Receipt = require('../models/Receipt');
const ReceiptItem = require('../models/ReceiptItem');
const asyncHandler = require('../utils/asyncHandler');
const { success } = require('../utils/response');

function dayRange(dateStr) {
  const target = dateStr ? new Date(dateStr) : new Date();
  const from = new Date(target);
  from.setHours(0, 0, 0, 0);
  const to = new Date(target);
  to.setHours(23, 59, 59, 999);
  return { $gte: from, $lte: to };
}

const getShareRecords = asyncHandler(async (req, res) => {
  const { date, marketId, session } = req.query;

  const filter = {
    status: 'Active',
    date: dayRange(date),
  };
  if (req.user.role !== 'admin') {
    filter.operator = req.user._id;
  }

  if (marketId && marketId.trim() !== '') {
    filter.market = marketId.trim();
  }

  if (session && session.trim() !== '' && session.trim() !== 'All') {
    filter.session = session.trim();
  }

  const receipts = await Receipt.find(filter)
    .populate('market', 'name code')
    .populate('operator', 'fullName username')
    .sort({ createdAt: 1 });

  const receiptIds = receipts.map((r) => r._id);
  const allItems = await ReceiptItem.find({ receipt: { $in: receiptIds } }).sort({ createdAt: 1 });

  const itemsMap = new Map();
  for (const item of allItems) {
    const key = item.receipt.toString();
    if (!itemsMap.has(key)) {
      itemsMap.set(key, []);
    }
    itemsMap.get(key).push(item);
  }

  let totalItemsCount = 0;
  let totalAmountSum = 0;

  const records = receipts.map((receipt) => {
    const rawItems = itemsMap.get(receipt._id.toString()) || [];
    const items = rawItems.map((item) => ({
      id: item._id.toString(),
      type: item.type,
      betType: item.betType,
      betSubtype: item.betSubtype,
      number: item.number,
      amount: item.amount,
      isJackpot: item.isJackpot === true,
      components: item.components,
    }));

    totalItemsCount += items.length;
    totalAmountSum += receipt.totalAmount || 0;

    return {
      receiptId: receipt._id.toString(),
      receiptNumber: receipt.receiptNumber,
      customerName: receipt.customerName || null,
      customerMobile: receipt.customerMobile || null,
      market: {
        id: receipt.market?._id?.toString() || receipt.market?.toString() || '',
        name: receipt.market?.name || 'ALL MARKETS',
        code: receipt.market?.code || '',
      },
      session: receipt.session,
      isOtc: receipt.isOtc === true,
      operator: {
        id: receipt.operator?._id?.toString() || receipt.operator?.toString() || '',
        name: receipt.operator?.fullName || receipt.operator?.username || 'Operator 01',
      },
      createdAt: receipt.createdAt,
      date: receipt.date,
      totalAmount: receipt.totalAmount,
      totalItems: receipt.totalItems || items.length,
      items,
    };
  });

  return success(res, {
    data: {
      summary: {
        totalReceipts: receipts.length,
        totalItems: totalItemsCount,
        totalAmount: totalAmountSum,
      },
      records,
    },
  });
});

module.exports = {
  getShareRecords,
};
