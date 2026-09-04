function getPagination(query, defaultLimit = 20) {
  const page = Math.max(1, Number.parseInt(query.page, 10) || 1);
  const requestedLimit = Number.parseInt(query.limit, 10) || defaultLimit;
  const limit = Math.min(100, Math.max(1, requestedLimit));
  return { page, limit, skip: (page - 1) * limit };
}

function paginationMeta(page, limit, total) {
  return {
    page,
    limit,
    total,
    totalPages: Math.max(1, Math.ceil(total / limit)),
  };
}

module.exports = { getPagination, paginationMeta };

