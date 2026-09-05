const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const app = require('../src/app');

test('GET /api/share-records rejects missing Bearer token', async () => {
  const response = await request(app).get('/api/share-records').expect(401);
  assert.equal(response.body.success, false);
  assert.match(response.body.message, /Bearer access token/i);
});
