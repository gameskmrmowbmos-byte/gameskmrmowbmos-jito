const express = require('express');
const authenticate = require('../middleware/auth.middleware');
const requireActiveSubscription = require('../middleware/subscription.middleware');
const authorize = require('../middleware/role.middleware');
const validate = require('../middleware/validate.middleware');
const controller = require('../controllers/receipt.controller');

const router = express.Router();

router.use(authenticate);

router.get('/', controller.listReceipts);
router.get('/search', controller.searchReceipt);
router.get('/:id', controller.getReceipt);
router.post('/', requireActiveSubscription, controller.createReceipt);
router.post('/:id/cancel', authorize('admin'), controller.cancelReceipt); // Only admin (or via PIN check)

module.exports = router;
