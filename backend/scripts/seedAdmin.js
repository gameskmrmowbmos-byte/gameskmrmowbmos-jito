const mongoose = require('mongoose');
const { connectDatabase, disconnectDatabase } = require('../src/config/database');
const User = require('../src/models/User');
const logger = require('../src/utils/logger');

async function seedAdmin() {
  const fullName = process.env.ADMIN_NAME;
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;

  if (!fullName || !email || !password) {
    throw new Error(
      'ADMIN_NAME, ADMIN_EMAIL, and ADMIN_PASSWORD must be set in .env',
    );
  }
  if (password.length < 10) {
    throw new Error('ADMIN_PASSWORD must contain at least 10 characters');
  }

  await connectDatabase();
  let admin = await User.findOne({ email }).select('+passwordHash');
  if (!admin) {
    admin = new User({
      fullName,
      username: email.split('@')[0],
      email,
      passwordHash: 'pending',
      role: 'admin',
      approvalStatus: 'APPROVED',
      accountStatus: 'ACTIVE',
      emailVerified: true,
      subscriptionType: 'PAID',
      subscriptionStatus: 'ACTIVE',
      isActive: true,
    });
    await admin.setPassword(password);
    await admin.save();
    logger.info(`Admin created for ${email}`);
  } else {
    admin.fullName = fullName;
    admin.username = admin.username || email.split('@')[0];
    admin.role = 'admin';
    admin.approvalStatus = 'APPROVED';
    admin.accountStatus = 'ACTIVE';
    admin.emailVerified = true;
    admin.subscriptionType = 'PAID';
    admin.subscriptionStatus = 'ACTIVE';
    admin.isActive = true;
    await admin.save();
    logger.info(`Existing admin updated for ${email}`);
  }
}

seedAdmin()
  .then(disconnectDatabase)
  .then(() => process.exit(0))
  .catch(async (error) => {
    logger.error('Admin seed failed', { message: error.message });
    await disconnectDatabase();
    process.exit(1);
  });

