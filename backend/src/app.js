const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const helmet = require('helmet');
const mongoSanitize = require('express-mongo-sanitize');
const morgan = require('morgan');
const env = require('./config/env');
const logger = require('./utils/logger');
const sanitizeRequest = require('./middleware/sanitize.middleware');
const { apiLimiter } = require('./middleware/rateLimit.middleware');
const { notFound, errorHandler } = require('./middleware/error.middleware');

const authRoutes = require('./routes/auth.routes');
const adminRoutes = require('./routes/admin.routes');
const userRoutes = require('./routes/user.routes');
const marketRoutes = require('./routes/market.routes');
const settingsRoutes = require('./routes/settings.routes');
const auditRoutes = require('./routes/audit.routes');
const receiptRoutes = require('./routes/receipt.routes');
const printRoutes = require('./routes/print.routes');
const shareRecordsRoutes = require('./routes/shareRecords.routes');
const subscriptionRoutes = require('./routes/subscription.routes');
const gameConfigRoutes = require('./routes/gameConfig.routes');

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);

const isAllowedOrigin = (origin) => {
  if (!origin) return true;
  // Always permit local development origins
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return true;
  const normalized = origin.replace(/\/+$/, '');
  return env.allowedOrigins.includes(normalized);
};

app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      if (!env.isProduction || isAllowedOrigin(origin)) return callback(null, true);
      return callback(null, false);
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Client-Platform', 'Accept', 'X-Requested-With'],
  }),
);
app.use(express.json({ limit: '200kb' }));
app.use(express.urlencoded({ extended: false, limit: '200kb' }));
app.use(cookieParser());
app.use(mongoSanitize({ replaceWith: '_' }));
app.use(sanitizeRequest);
app.use(
  morgan(env.isProduction ? 'combined' : 'dev', {
    stream: { write: (message) => logger.http(message.trim()) },
  }),
);
app.use('/api', apiLimiter);

app.get('/api/health', (_req, res) =>
  res.status(200).json({
    success: true,
    message: 'API is healthy',
    data: { service: 'matka-management-api', demoOnly: true },
  }),
);

app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/subscription', subscriptionRoutes);
app.use('/api/users', userRoutes);
app.use('/api/markets', marketRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/audit-logs', auditRoutes);
app.use('/api/receipts', receiptRoutes);
app.use('/api/prints', printRoutes);
app.use('/api/share-records', shareRecordsRoutes);
app.use('/api/game-configs', gameConfigRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;

