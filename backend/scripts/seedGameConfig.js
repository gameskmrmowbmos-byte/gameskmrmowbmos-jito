const { connectDatabase, disconnectDatabase } = require('../src/config/database');
const { upsertStandardGameConfig } = require('../src/services/gameConfig.service');
const logger = require('../src/utils/logger');

async function seedGameConfig() {
  await connectDatabase();
  const result = await upsertStandardGameConfig();

  logger.info('STANDARD_GAME_CONFIG seeded');
  logger.info(`Active markets matched: ${result.matchedMarkets}`);
  logger.info(`Active markets updated: ${result.assignedMarkets}`);
  logger.info(`STANDARD_220_PANNA supplied entries: ${result.analysis.totalSuppliedEntries}`);
  logger.info(`STANDARD_220_PANNA unique entries: ${result.analysis.uniqueEntries}`);
  if (result.analysis.duplicateValues.length) {
    logger.warn('STANDARD_220_PANNA duplicate values found', {
      duplicates: result.analysis.duplicateValues,
    });
  }
  if (result.analysis.invalidStringLengths.length) {
    logger.warn('STANDARD_220_PANNA invalid string lengths found', {
      invalid: result.analysis.invalidStringLengths,
    });
  }
  logger.info(`STANDARD_PANNA_MOTORS supplied entries: ${result.motorAnalysis.totalSuppliedEntries}`);
  logger.info(`STANDARD_PANNA_MOTORS unique entries: ${result.motorAnalysis.uniqueEntries}`);
  logger.info(`STANDARD_PANNA_MOTORS stored entries: ${result.motorNumberSet.values.length}`);
  if (result.motorAnalysis.duplicateValues.length) {
    logger.warn('STANDARD_PANNA_MOTORS duplicate values found', {
      duplicateCount: result.motorAnalysis.duplicateValues.length,
    });
  }

  return result;
}

seedGameConfig()
  .then(disconnectDatabase)
  .then(() => process.exit(0))
  .catch(async (error) => {
    logger.error('Game config seed failed', {
      message: error.message,
      stack: error.stack,
    });
    await disconnectDatabase();
    process.exit(1);
  });
