const path = require('path');
const fs = require('fs');
const winston = require('winston');
const env = require('../config/env');

const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.printf(({ level, message, timestamp }) => {
    const normalizedLevel = level.toUpperCase();
    return `${timestamp} [${normalizedLevel}] ${message}`;
  }),
);

const transports = [
  new winston.transports.Console({
    format: consoleFormat,
  }),
];

if (env.isProduction) {
  const logDirectory = path.join(process.cwd(), 'logs');
  fs.mkdirSync(logDirectory, { recursive: true });
  transports.push(
    new winston.transports.File({
      filename: path.join(logDirectory, 'application.log'),
      format: winston.format.json(),
    }),
  );
}

module.exports = winston.createLogger({
  level: env.logLevel,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: !env.isProduction }),
    winston.format.json(),
  ),
  transports,
});

