const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const app = require('../src/app');

test('GET /api/health returns the documented envelope', async () => {
  const response = await request(app).get('/api/health').expect(200);
  assert.equal(response.body.success, true);
  assert.equal(response.body.data.demoOnly, true);
});

test('unknown API route returns sanitized 404 response', async () => {
  const response = await request(app).get('/api/does-not-exist').expect(404);
  assert.equal(response.body.success, false);
  assert.match(response.body.message, /not found/i);
});

test('protected route rejects a missing Bearer token', async () => {
  const response = await request(app).get('/api/receipts').expect(401);
  assert.equal(response.body.success, false);
  assert.match(response.body.message, /Bearer access token/i);
});

