const express = require('express');
const { body, param } = require('express-validator');
const controller = require('../controllers/user.controller');
const authenticate = require('../middleware/auth.middleware');
const authorize = require('../middleware/role.middleware');
const validate = require('../middleware/validate.middleware');
const {
  createUserRules,
  updateUserRules,
} = require('../validators/user.validator');

const router = express.Router();
router.use(authenticate, authorize('admin'));

router
  .route('/')
  .get(controller.listUsers)
  .post(createUserRules, validate, controller.createUser);

router.patch(
  '/:id/status',
  [
    param('id').isMongoId().withMessage('Invalid operator ID'),
    body('isActive').isBoolean().withMessage('Active status is required'),
  ],
  validate,
  controller.updateStatus,
);
router.post(
  '/:id/reset-password',
  [
    param('id').isMongoId().withMessage('Invalid operator ID'),
    body('password')
      .isLength({ min: 10, max: 128 })
      .matches(/[a-z]/)
      .matches(/[A-Z]/)
      .matches(/\d/)
      .matches(/[^A-Za-z0-9]/)
      .withMessage('A strong password is required'),
  ],
  validate,
  controller.resetUserPassword,
);
router
  .route('/:id')
  .get(
    param('id').isMongoId().withMessage('Invalid operator ID'),
    validate,
    controller.getUser,
  )
  .put(
    param('id').isMongoId().withMessage('Invalid operator ID'),
    updateUserRules,
    validate,
    controller.updateUser,
  )
  .delete(
    param('id').isMongoId().withMessage('Invalid operator ID'),
    validate,
    controller.deleteUser,
  );

module.exports = router;

