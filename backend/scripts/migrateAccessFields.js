const { connectDatabase, disconnectDatabase } = require('../src/config/database');
const User = require('../src/models/User');
const logger = require('../src/utils/logger');

async function migrateAccessFields() {
  await connectDatabase();

  const result = await User.updateMany(
    {
      $or: [
        { approvalStatus: { $exists: false } },
        { accountStatus: { $exists: false } },
        { subscriptionStatus: { $exists: false } },
        { subscriptionType: { $exists: false } },
        { emailVerified: { $exists: false } },
      ],
    },
    [
      {
        $set: {
          approvalStatus: { $ifNull: ['$approvalStatus', 'APPROVED'] },
          accountStatus: {
            $ifNull: [
              '$accountStatus',
              { $cond: [{ $eq: ['$isActive', true] }, 'ACTIVE', 'DISABLED'] },
            ],
          },
          subscriptionStatus: {
            $ifNull: [
              '$subscriptionStatus',
              { $cond: [{ $eq: ['$role', 'admin'] }, 'ACTIVE', 'NOT_ACTIVE'] },
            ],
          },
          subscriptionType: {
            $ifNull: [
              '$subscriptionType',
              { $cond: [{ $eq: ['$subscriptionStatus', 'ACTIVE'] }, 'PAID', 'NONE'] },
            ],
          },
          emailVerified: { $ifNull: ['$emailVerified', true] },
        },
      },
    ],
  );

  logger.info('Access field migration complete', {
    matched: result.matchedCount,
    modified: result.modifiedCount,
  });
}

migrateAccessFields()
  .then(disconnectDatabase)
  .then(() => process.exit(0))
  .catch(async (error) => {
    logger.error('Access field migration failed', {
      message: error.message,
      stack: error.stack,
    });
    await disconnectDatabase();
    process.exit(1);
  });
