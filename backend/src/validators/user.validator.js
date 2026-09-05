const { body } = require('express-validator');

const optionalPassword = body('password')
  .optional()
  .isLength({ min: 10, max: 128 })
  .withMessage('Password must be between 10 and 128 characters')
  .matches(/[a-z]/)
  .withMessage('Password must contain a lowercase letter')
  .matches(/[A-Z]/)
  .withMessage('Password must contain an uppercase letter')
  .matches(/\d/)
  .withMessage('Password must contain a number')
  .matches(/[^A-Za-z0-9]/)
  .withMessage('Password must contain a special character');

const commonRules = [
  body('fullName')
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Full name must be 2 to 100 characters'),
  body('username')
    .trim()
    .matches(/^[A-Za-z0-9_.-]{3,40}$/)
    .withMessage('Username must be 3 to 40 valid characters'),
  body('email').trim().isEmail().withMessage('Valid email is required').normalizeEmail(),
  body('phoneNumber')
    .optional({ values: 'falsy' })
    .trim()
    .matches(/^[+0-9 ()-]{7,20}$/)
    .withMessage('Phone number format is invalid'),
  body('assignedMarkets')
    .optional()
    .isArray()
    .withMessage('Assigned markets must be an array'),
  body('assignedMarkets.*')
    .optional()
    .isMongoId()
    .withMessage('Assigned market ID is invalid'),
  body('isActive').optional().isBoolean().withMessage('Active status must be boolean'),
];

const createUserRules = [
  ...commonRules,
  body('password')
    .isLength({ min: 10, max: 128 })
    .withMessage('Password must be between 10 and 128 characters')
    .matches(/[a-z]/)
    .withMessage('Password must contain a lowercase letter')
    .matches(/[A-Z]/)
    .withMessage('Password must contain an uppercase letter')
    .matches(/\d/)
    .withMessage('Password must contain a number')
    .matches(/[^A-Za-z0-9]/)
    .withMessage('Password must contain a special character'),
];

const updateUserRules = [...commonRules, optionalPassword];

module.exports = { createUserRules, updateUserRules };

