function success(res, { statusCode = 200, message, data = {}, pagination } = {}) {
  const payload = {
    success: true,
    message: message || 'Operation completed successfully',
    data,
  };

  if (pagination) payload.pagination = pagination;
  return res.status(statusCode).json(payload);
}

module.exports = { success };

