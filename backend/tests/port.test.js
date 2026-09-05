const test = require('node:test');
const assert = require('node:assert/strict');
const net = require('net');
const { getNextAvailablePort } = require('../src/utils/port');

test('falls back to the next free port when the preferred port is busy', async () => {
  const preferredPort = 5102;
  const occupiedServer = net.createServer();

  await new Promise((resolve, reject) => {
    occupiedServer.once('error', reject);
    occupiedServer.listen(preferredPort, '127.0.0.1', resolve);
  });

  try {
    const nextPort = await getNextAvailablePort(preferredPort, '127.0.0.1', 3);
    assert.equal(nextPort, preferredPort + 1);
  } finally {
    await new Promise((resolve) => occupiedServer.close(resolve));
  }
});
