const http = require('http');
const app = require('./app');
const env = require('./config/env');
const { connectDatabase, disconnectDatabase } = require('./config/database');
const logger = require('./utils/logger');
const { listenWithFallback } = require('./utils/port');

let server;

async function start() {
  await connectDatabase();
  const { server: listeningServer, port } = await listenWithFallback(
    () => http.createServer(app),
    env.port,
    env.host,
    10,
  );

  server = listeningServer;
  logger.info(`API listening on port ${port}`);
}

async function shutdown(signal) {
  logger.info(`${signal} received; shutting down`);
  if (server) {
    await new Promise((resolve) => server.close(resolve));
  }
  await disconnectDatabase();
  process.exit(0);
}

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => shutdown(signal));
}

process.on('unhandledRejection', (error) => {
  logger.error('Unhandled promise rejection', { error });
});

start().catch((error) => {
  logger.error('API startup failed', { message: error.message, stack: error.stack });
  process.exit(1);
});
