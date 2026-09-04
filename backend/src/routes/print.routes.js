const express = require('express');
const authenticate = require('../middleware/auth.middleware');
const controller = require('../controllers/print.controller');

const router = express.Router();

router.use(authenticate);

router.get('/search', controller.findByPrintId);
router.get('/', controller.listPrintLogs);
router.post('/', controller.createPrintLog);
router.get('/:id', controller.getPrintLog);

module.exports = router;
