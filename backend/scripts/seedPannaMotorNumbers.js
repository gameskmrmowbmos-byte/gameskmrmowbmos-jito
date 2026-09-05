const { connectDatabase, disconnectDatabase } = require('../src/config/database');
const {
  standardPannaMotorNumberSetPayload,
  upsertStandardPannaMotorNumberSet,
} = require('../src/services/gameConfig.service');
const logger = require('../src/utils/logger');

async function seedPannaMotorNumbers() {
  const { analysis, payload } = standardPannaMotorNumberSetPayload();

  logger.info(`${payload.code} supplied entries: ${analysis.totalSuppliedEntries}`);
  logger.info(`${payload.code} unique entries: ${analysis.uniqueEntries}`);
  logger.info(`${payload.code} motor groups: ${payload.groups.length}`);
  if (analysis.duplicateValues.length) {
    logger.warn(`${payload.code} duplicate values found before upsert: ${analysis.duplicateValues.length}`);
  }

  await connectDatabase();
  const result = await upsertStandardPannaMotorNumberSet();

  logger.info(`${payload.code} seeded`);
  logger.info(`${payload.code} stored entries: ${result.numberSet.values.length}`);

  return result;
}

seedPannaMotorNumbers()
  .then(disconnectDatabase)
  .then(() => process.exit(0))
  .catch(async (error) => {
    logger.error('Panna motor number seed failed', {
      message: error.message,
      stack: error.stack,
    });
    await disconnectDatabase();
    process.exit(1);
  });
