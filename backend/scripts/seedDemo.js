const { connectDatabase, disconnectDatabase } = require('../src/config/database');
const User = require('../src/models/User');
const Market = require('../src/models/Market');
const Receipt = require('../src/models/Receipt');
const ReceiptItem = require('../src/models/ReceiptItem');
const Settings = require('../src/models/Settings');
const { upsertStandardGameConfig } = require('../src/services/gameConfig.service');
const logger = require('../src/utils/logger');

const seedNote = 'Seeded sample data';

async function ensureUser(data, password) {
  let user = await User.findOne({
    $or: [{ email: data.email }, { username: data.username }],
  }).select('+passwordHash');

  if (!user) {
    user = new User({ ...data, passwordHash: 'pending' });
    await user.setPassword(password);
  } else {
    Object.assign(user, data);
    if (password) await user.setPassword(password);
  }

  await user.save();
  return user;
}

function receiptDate(hours, minutes = 0) {
  const value = new Date();
  value.setHours(hours, minutes, 0, 0);
  return value;
}

async function createReceipt({ receiptNumber, date, market, session, operator, customerName, customerMobile, items }) {
  const receipt = await Receipt.create({
    receiptNumber,
    date,
    market: market._id,
    session,
    operator: operator._id,
    totalAmount: items.reduce((sum, item) => sum + item.amount, 0),
    totalItems: items.length,
    customerName,
    customerMobile,
    notes: seedNote,
    printStatus: 'Not Printed',
  });

  await ReceiptItem.insertMany(
    items.map((item) => ({
      ...item,
      receipt: receipt._id,
      jackpotEnabled: item.jackpotEnabled === true,
    })),
  );

  return receipt;
}

async function seedDemo() {
  const adminPassword = process.env.ADMIN_PASSWORD || 'Admin@12345';
  const operatorPassword = process.env.DEMO_OPERATOR_PASSWORD || 'Operator@12345';
  const adminEmail = (process.env.ADMIN_EMAIL || 'admin@example.com').trim().toLowerCase();

  await connectDatabase();
  await upsertStandardGameConfig();

  const admin = await ensureUser(
    {
      fullName: process.env.ADMIN_NAME || 'System Admin',
      username: process.env.ADMIN_USERNAME || 'admin',
      email: adminEmail,
      role: 'admin',
      approvalStatus: 'APPROVED',
      accountStatus: 'ACTIVE',
      emailVerified: true,
      subscriptionType: 'PAID',
      subscriptionStatus: 'ACTIVE',
      assignedMarkets: [],
      isActive: true,
    },
    adminPassword,
  );

  const marketDefinitions = [
    {
      name: 'KALYAN',
      code: 'KALYAN',
      openingTime: '09:30',
      closingTime: '23:30',
      resultTime: '23:45',
      description: 'Sample market for local testing.',
    },
    {
      name: 'MILAN',
      code: 'MILAN',
      openingTime: '10:00',
      closingTime: '22:45',
      resultTime: '23:00',
      description: 'Sample market for local testing.',
    },
    {
      name: 'RAJDHANI',
      code: 'RAJDHANI',
      openingTime: '11:00',
      closingTime: '21:30',
      resultTime: '21:45',
      description: 'Sample market for local testing.',
    },
  ];

  const markets = [];
  for (const definition of marketDefinitions) {
    const market = await Market.findOneAndUpdate(
      { code: definition.code },
      { ...definition, isActive: true, createdBy: admin._id },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );
    markets.push(market);
  }

  const operatorOne = await ensureUser(
    {
      fullName: 'Sample Operator One',
      username: 'operator1',
      email: 'operator1@example.com',
      role: 'operator',
      approvalStatus: 'APPROVED',
      accountStatus: 'ACTIVE',
      emailVerified: true,
      subscriptionType: 'PAID',
      subscriptionStatus: 'ACTIVE',
      subscriptionStartDate: new Date(),
      subscriptionExpiryDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      rechargeStartDate: new Date(),
      rechargeEndDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      assignedMarkets: [markets[0]._id, markets[1]._id],
      isActive: true,
    },
    operatorPassword,
  );

  const operatorTwo = await ensureUser(
    {
      fullName: 'Sample Operator Two',
      username: 'operator2',
      email: 'operator2@example.com',
      role: 'operator',
      approvalStatus: 'APPROVED',
      accountStatus: 'ACTIVE',
      emailVerified: true,
      subscriptionType: 'PAID',
      subscriptionStatus: 'ACTIVE',
      subscriptionStartDate: new Date(),
      subscriptionExpiryDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      rechargeStartDate: new Date(),
      rechargeEndDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      assignedMarkets: [markets[0]._id, markets[2]._id],
      isActive: true,
    },
    operatorPassword,
  );

  await User.updateOne(
    { _id: admin._id },
    { assignedMarkets: markets.map((market) => market._id) },
  );

  const oldReceipts = await Receipt.find({ notes: seedNote }).select('_id');
  const oldReceiptIds = oldReceipts.map((receipt) => receipt._id);
  if (oldReceiptIds.length) {
    await ReceiptItem.deleteMany({ receipt: { $in: oldReceiptIds } });
    await Receipt.deleteMany({ _id: { $in: oldReceiptIds } });
  }

  const todayStamp = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  await createReceipt({
    receiptNumber: `RC-${todayStamp}-9001`,
    date: receiptDate(10, 15),
    market: markets[0],
    session: 'Open',
    operator: operatorOne,
    customerName: 'Sample Customer A',
    customerMobile: '9000000001',
    items: [
      { type: 'Single', number: '4', amount: 20, jackpotEnabled: true },
      { type: 'Jodi', number: '47', amount: 50 },
      { type: 'Patti', number: '257', amount: 30, jackpotEnabled: true },
    ],
  });

  await createReceipt({
    receiptNumber: `RC-${todayStamp}-9002`,
    date: receiptDate(11, 5),
    market: markets[0],
    session: 'Close',
    operator: operatorTwo,
    customerName: 'Sample Customer B',
    customerMobile: '9000000002',
    items: [
      { type: 'Single', number: '9', amount: 10 },
      { type: 'Jodi', number: '18', amount: 40 },
    ],
  });

  await createReceipt({
    receiptNumber: `RC-${todayStamp}-9003`,
    date: receiptDate(12, 20),
    market: markets[1],
    session: 'Open',
    operator: operatorOne,
    customerName: 'Sample Customer C',
    customerMobile: '9000000003',
    items: [
      { type: 'Half Sangam', number: '12-345', amount: 75 },
      { type: 'Full Sangam', number: '123-45-678', amount: 125 },
    ],
  });

  const settings = await Settings.findOneAndUpdate(
    { singletonKey: 'application' },
    {
      applicationName: 'Matka Entry System',
      businessName: 'Sample Business',
      defaultMarket: markets[0]._id,
      defaultSession: 'Open',
      allowEntryEditing: true,
      editingCutoffMinutes: 0,
      paginationSize: 20,
      sessionTimeoutMinutes: 60,
      updatedBy: admin._id,
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  ).select('+adminPin +adminPinHash');

  if (!settings.adminPinHash) {
    await settings.setAdminPin(process.env.ADMIN_PIN || '1234');
    await settings.save();
  }

  logger.info('Sample users, markets, receipts, receipt items, and settings seeded');
  logger.info(`Admin login: ${admin.username} / ${adminPassword}`);
  logger.info(`Operator login: ${operatorOne.username} / ${operatorPassword}`);
}

seedDemo()
  .then(disconnectDatabase)
  .then(() => process.exit(0))
  .catch(async (error) => {
    logger.error('Demo seed failed', { message: error.message, stack: error.stack });
    await disconnectDatabase();
    process.exit(1);
  });
