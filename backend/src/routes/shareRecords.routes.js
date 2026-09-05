const express = require('express');
const authenticate = require('../middleware/auth.middleware');
const controller = require('../controllers/shareRecords.controller');

const router = express.Router();

router.use(authenticate);

router.get('/', controller.getShareRecords);

module.exports = router;
