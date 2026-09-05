const { connectDatabase, disconnectDatabase } = require('../src/config/database');
const {
  standardPannaNumberSetPayload,
  upsertStandardPannaNumberSetAndLinkConfig,
} = require('../src/services/gameConfig.service');
const logger = require('../src/utils/logger');

async function seedPannaNumbers() {
  const { analysis } = standardPannaNumberSetPayload();

  logger.info(`STANDARD_220_PANNA supplied entries: ${analysis.totalSuppliedEntries}`);
  logger.info(`STANDARD_220_PANNA unique entries: ${analysis.uniqueEntries}`);
  if (analysis.duplicateValues.length) {
    logger.warn('STANDARD_220_PANNA duplicate values found before upsert', {
      duplicates: analysis.duplicateValues,
    });
  }

  await connectDatabase();
  const result = await upsertStandardPannaNumberSetAndLinkConfig();

  logger.info('STANDARD_220_PANNA seeded');
  logger.info(`STANDARD_220_PANNA stored entries: ${result.numberSet.values.length}`);
  logger.info(`STANDARD_220_PANNA linked config: ${result.gameConfig.code}`);

  return result;
}

seedPannaNumbers()
  .then(disconnectDatabase)
  .then(() => process.exit(0))
  .catch(async (error) => {
    logger.error('Panna number seed failed', {
      message: error.message,
      stack: error.stack,
    });
    await disconnectDatabase();
    process.exit(1);
  });
