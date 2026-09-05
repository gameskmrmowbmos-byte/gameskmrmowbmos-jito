const test = require('node:test');
const assert = require('node:assert/strict');
const { escapeCsv, toCsv } = require('../src/utils/csv');
const { getPagination, paginationMeta } = require('../src/utils/pagination');
const {
  categoryPatterns,
} = require('../src/validators/entry.validator');
const {
  isSameLocalDate,
  minutesFromTime,
} = require('../src/services/entryPolicy.service');

test('CSV encoding protects commas, quotes, and line breaks', () => {
  assert.equal(escapeCsv('a,b'), '"a,b"');
  assert.equal(escapeCsv('a"b'), '"a""b"');
  assert.equal(
    toCsv([{ label: 'Name', value: (row) => row.name }], [{ name: 'A,B' }]),
    'Name\n"A,B"',
  );
});

test('pagination applies safe defaults and maximum', () => {
  assert.deepEqual(getPagination({ page: '-1', limit: '500' }), {
    page: 1,
    limit: 100,
    skip: 0,
  });
  assert.deepEqual(paginationMeta(2, 20, 41), {
    page: 2,
    limit: 20,
    total: 41,
    totalPages: 3,
  });
});

test('entry category patterns implement documented formats', () => {
  assert.equal(categoryPatterns.single_digit.test('9'), true);
  assert.equal(categoryPatterns.single_digit.test('10'), false);
  assert.equal(categoryPatterns.jodi.test('00'), true);
  assert.equal(categoryPatterns.single_panna.test('123'), true);
  assert.equal(categoryPatterns.full_sangam.test('123-456'), true);
});

test('entry time helpers are deterministic', () => {
  assert.equal(minutesFromTime('16:30'), 990);
  assert.equal(
    isSameLocalDate(
      new Date(2026, 6, 31, 1),
      new Date(2026, 6, 31, 23),
    ),
    true,
  );
});

