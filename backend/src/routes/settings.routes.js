const express = require('express');
const { body } = require('express-validator');
const controller = require('../controllers/settings.controller');
const authenticate = require('../middleware/auth.middleware');
const authorize = require('../middleware/role.middleware');
const validate = require('../middleware/validate.middleware');

const router = express.Router();
router.use(authenticate, authorize('admin'));

const pinRules = [
  body('pin').optional().isLength({ min: 4, max: 12 }),
  body('currentPin').optional().isLength({ min: 4, max: 12 }),
  body('newPin').optional().isLength({ min: 4, max: 12 }),
];

const settingsRules = [
  body('applicationName').optional().trim().isLength({ min: 2, max: 100 }),
  body('businessName').optional().trim().isLength({ min: 2, max: 100 }),
  body('address').optional().trim().isLength({ max: 500 }),
  body('contactNumber').optional().trim().isLength({ max: 20 }),
  body('alternateNumber').optional().trim().isLength({ max: 20 }),
  body('retentionPeriodDays').optional().isInt({ min: 1, max: 3650 }),
  body('sessionTimeoutMinutes').optional().isInt({ min: 5, max: 1440 }),
  body('defaultCopies').optional().isInt({ min: 1, max: 10 }),
];

router.get('/', controller.getSettings);
router.put('/', settingsRules, validate, controller.updateSettings);
router.put('/general', settingsRules, validate, controller.updateGeneral);
router.put('/printing', settingsRules, validate, controller.updatePrinting);
router.put('/security', settingsRules, validate, controller.updateSecurity);
router.put('/retention', settingsRules, validate, controller.updateRetention);
router.put('/backup', settingsRules, validate, controller.updateBackup);
router.put('/other', settingsRules, validate, controller.updateOther);
router.post('/verify-admin-pin', pinRules, validate, controller.verifyAdminPin);
router.post('/change-admin-pin', pinRules, validate, controller.changeAdminPin);
router.get('/database-health', controller.databaseHealth);
router.post('/run-backup', controller.runBackup);
router.post(
  '/run-cleanup',
  body('confirmation').equals('DELETE_OLD_RECORDS').withMessage('Explicit cleanup confirmation is required'),
  validate,
  controller.runCleanup,
);

module.exports = router;
