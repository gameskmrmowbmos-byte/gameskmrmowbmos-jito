const { body } = require('express-validator');

const timePattern = /^([01]\d|2[0-3]):[0-5]\d$/;

const marketRules = [
  body('name')
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Market name must be 2 to 100 characters'),
  body('code')
    .trim()
    .matches(/^[A-Za-z0-9_-]{2,20}$/)
    .withMessage('Code must use 2 to 20 letters, numbers, underscores, or hyphens'),
  body('resultTime')
    .matches(timePattern)
    .withMessage('Result time must use HH:mm format'),
  body('description')
    .optional({ values: 'falsy' })
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description cannot exceed 500 characters'),
  body('isActive').optional().isBoolean().withMessage('Active status must be boolean'),
  body('gameConfigCode')
    .optional({ values: 'falsy' })
    .trim()
    .matches(/^[A-Za-z0-9_-]{2,50}$/)
    .withMessage('Game config code must use 2 to 50 letters, numbers, underscores, or hyphens'),
];

module.exports = { marketRules };

