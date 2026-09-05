const express = require('express');
const { body, param } = require('express-validator');
const authenticate = require('../middleware/auth.middleware');
const requireAdmin = require('../middleware/admin.middleware');
const validate = require('../middleware/validate.middleware');
const controller = require('../controllers/admin.controller');

const router = express.Router();

router.use(authenticate, requireAdmin);

const mongoId = (name = 'id') => param(name).isMongoId().withMessage('Invalid ID');
const optionalMoney = body('amount').optional().isFloat({ min: 0 }).withMessage('Amount must be zero or greater');
const planRules = [
  body('name').trim().isLength({ min: 2, max: 100 }),
  body('code').trim().isLength({ min: 2, max: 40 }),
  body('validityDays').isInt({ min: 1, max: 3650 }),
  body('price').isFloat({ min: 0 }),
  body('description').optional().trim().isLength({ max: 500 }),
  body('isActive').optional().isBoolean(),
];

const marketRules = [
  body('name').trim().isLength({ min: 2, max: 100 }),
  body('code').trim().isLength({ min: 2, max: 20 }),
  body('resultTime').matches(/^([01]\d|2[0-3]):[0-5]\d$/),
  body('description').optional().trim().isLength({ max: 500 }),
  body('isActive').optional().isBoolean(),
];

const marketReorderRules = [
  body('marketIds').isArray({ min: 1 }).withMessage('marketIds must be a non-empty array'),
  body('marketIds.*').isMongoId().withMessage('Invalid market ID'),
];

router.get('/dashboard', controller.dashboard);

router.get('/users', controller.listUsers);
router.get('/users/:id', mongoId(), validate, controller.getUser);
router.post('/users/:id/approve', mongoId(), validate, controller.approveUser);
router.post('/users/:id/reject', mongoId(), validate, controller.rejectUser);
router.post('/users/:id/block', mongoId(), validate, controller.blockUser);
router.post('/users/:id/unblock', mongoId(), validate, controller.unblockUser);
router.post('/users/:id/reset-device', mongoId(), validate, controller.resetDeviceLogin);
router.post('/users/:id/activate', mongoId(), validate, controller.activateUser);
router.post('/users/:id/disable', mongoId(), validate, controller.disableUser);
router.post(
  '/users/:id/recharge',
  [
    mongoId(),
    body('planId').optional().isMongoId(),
    body('validityDays').optional().isInt({ min: 1, max: 3650 }),
    body('customExpiryDate').optional().isISO8601(),
    optionalMoney,
    body('startMode').optional().isIn(['FROM_CURRENT_EXPIRY', 'FROM_TODAY']),
    body('paymentMode').optional().isIn(['Cash', 'UPI', 'Bank Transfer', 'Other']),
    body('paymentReference').optional().trim().isLength({ max: 100 }),
    body('note').optional().trim().isLength({ max: 500 }),
  ],
  validate,
  controller.rechargeUser,
);
router.get('/users/:id/recharges', mongoId(), validate, controller.userRecharges);

router.get('/recharges', controller.listRecharges);

router.get('/plans', controller.listPlans);
router.post('/plans', planRules, validate, controller.createPlan);
router.put('/plans/:id', [mongoId(), ...planRules], validate, controller.updatePlan);
router.post('/plans/:id/activate', mongoId(), validate, controller.setPlanStatus);
router.post('/plans/:id/deactivate', mongoId(), validate, controller.setPlanStatus);

router.get('/markets', controller.listMarkets);
router.post('/markets', marketRules, validate, controller.upsertMarket);
router.put('/markets/reorder', marketReorderRules, validate, controller.reorderMarketList);
router.put('/markets/:id', [mongoId(), ...marketRules], validate, controller.upsertMarket);
router.post('/markets/:id/activate', mongoId(), validate, controller.setMarketStatus);
router.post('/markets/:id/deactivate', mongoId(), validate, controller.setMarketStatus);
router.delete('/markets/:id', mongoId(), validate, controller.deleteMarket);

router.get('/number-config', controller.numberConfig);
router.get('/audit-logs', controller.listAuditLogs);
router.get('/settings', controller.getAdminSettings);
router.put(
  '/settings',
  [
    body('applicationName').optional().trim().isLength({ min: 2, max: 100 }),
    body('subscriptionWarningDays').optional().isInt({ min: 1, max: 60 }),
    body('allowNewRegistrations').optional().isBoolean(),
    body('requireManualApproval').optional().isBoolean(),
    body('defaultApprovalStatus').optional().isIn(['PENDING', 'APPROVED']),
    body('supportMobileNumber').optional().trim().isLength({ max: 20 }),
    body('supportWhatsAppNumber').optional().trim().isLength({ max: 20 }),
    body('singleDeviceLoginEnabled').optional().isBoolean(),
  ],
  validate,
  controller.updateAdminSettings,
);

module.exports = router;
