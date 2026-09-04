const forbiddenKeys = new Set(['__proto__', 'prototype', 'constructor']);

function sanitizeValue(value) {
  if (Array.isArray(value)) return value.map(sanitizeValue);
  if (!value || typeof value !== 'object') return value;

  return Object.fromEntries(
    Object.entries(value)
      .filter(([key]) => !key.startsWith('$') && !key.includes('.') && !forbiddenKeys.has(key))
      .map(([key, nested]) => [key, sanitizeValue(nested)]),
  );
}

function sanitizeRequest(req, _res, next) {
  if (req.body) req.body = sanitizeValue(req.body);
  next();
}

module.exports = sanitizeRequest;
