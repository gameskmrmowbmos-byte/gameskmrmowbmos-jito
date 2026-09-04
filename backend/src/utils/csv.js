function escapeCsv(value) {
  if (value === null || value === undefined) return '';
  const stringValue = String(value);
  if (/[",\n]/.test(stringValue)) {
    return `"${stringValue.replaceAll('"', '""')}"`;
  }
  return stringValue;
}

function toCsv(columns, rows) {
  const header = columns.map((column) => escapeCsv(column.label)).join(',');
  const body = rows.map((row) =>
    columns.map((column) => escapeCsv(column.value(row))).join(','),
  );
  return [header, ...body].join('\n');
}

module.exports = { escapeCsv, toCsv };
