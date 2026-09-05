const express = require('express');
const authenticate = require('../middleware/auth.middleware');
const controller = require('../controllers/gameConfig.controller');

const router = express.Router();

router.use(authenticate);
router.get('/current', controller.current);

module.exports = router;
