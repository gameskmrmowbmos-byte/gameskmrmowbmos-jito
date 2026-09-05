const mongoose = require('mongoose');
const env = require('./env');
const logger = require('../utils/logger');

async function connectDatabase() {
  mongoose.set('strictQuery', true);

  await mongoose.connect(env.mongoUri, {
    serverSelectionTimeoutMS: 10000,
  });

  if (mongoose.connection.name === 'test') {
    await mongoose.disconnect();
    throw new Error(
      'Unsafe MongoDB database "test" selected. Add an explicit database name to MONGODB_URI, for example /matka_management before query parameters.',
    );
  }

  logger.info(`MongoDB connected successfully to ${mongoose.connection.name}`);
  return mongoose.connection;
}

async function disconnectDatabase() {
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }
}

module.exports = { connectDatabase, disconnectDatabase };

