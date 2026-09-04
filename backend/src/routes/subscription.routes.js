const express = require('express');
const authenticate = require('../middleware/auth.middleware');
const controller = require('../controllers/subscription.controller');

const router = express.Router();

router.get('/status', authenticate, controller.getStatus);

module.exports = router;
