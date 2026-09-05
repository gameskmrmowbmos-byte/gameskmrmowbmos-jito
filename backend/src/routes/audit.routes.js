const express = require('express');
const controller = require('../controllers/audit.controller');
const authenticate = require('../middleware/auth.middleware');
const authorize = require('../middleware/role.middleware');

const router = express.Router();
router.get('/', authenticate, authorize('admin'), controller.listAuditLogs);

module.exports = router;

