const forbiddenKeys = new Set(['__proto__', 'prototype', 'constructor']);

function sanitizeValue(value) {
  if (Array.isArray(value)) return value.map(sanitizeValue);
  if (!value || typeof value !== 'object') return value;

  const sanitized = {};
  for (const [key, nested] of Object.entries(value)) {
    if (!key.startsWith('$') && !key.includes('.') && !forbiddenKeys.has(key)) {
      sanitized[key] = sanitizeValue(nested);
    }
  }
  return sanitized;
}

function sanitizeRequest(req, _res, next) {
  if (req.body) req.body = sanitizeValue(req.body);
  next();
}

module.exports = sanitizeRequest;
