const express = require('express');
const { body, param } = require('express-validator');
const controller = require('../controllers/market.controller');
const authenticate = require('../middleware/auth.middleware');
const authorize = require('../middleware/role.middleware');
const validate = require('../middleware/validate.middleware');
const { marketRules } = require('../validators/market.validator');

const router = express.Router();
router.use(authenticate);

router
  .route('/')
  .get(controller.listMarkets)
  .post(authorize('admin'), marketRules, validate, controller.createMarket);

router.patch(
  '/:id/status',
  authorize('admin'),
  [
    param('id').isMongoId().withMessage('Invalid market ID'),
    body('isActive').isBoolean().withMessage('Active status is required'),
  ],
  validate,
  controller.updateStatus,
);
router
  .route('/:id')
  .get(
    param('id').isMongoId().withMessage('Invalid market ID'),
    validate,
    controller.getMarket,
  )
  .put(
    authorize('admin'),
    param('id').isMongoId().withMessage('Invalid market ID'),
    marketRules,
    validate,
    controller.updateMarket,
  )
  .delete(
    authorize('admin'),
    param('id').isMongoId().withMessage('Invalid market ID'),
    validate,
    controller.deleteMarket,
  );

module.exports = router;

