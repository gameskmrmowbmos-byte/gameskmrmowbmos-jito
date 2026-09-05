const net = require('net');

function getPortFromEnv(portValue) {
  const parsed = Number(portValue);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

async function isPortAvailable(port, host = '0.0.0.0') {
  return new Promise((resolve) => {
    const server = net.createServer();

    server.once('error', (error) => {
      if (error.code === 'EADDRINUSE') {
        resolve(false);
      } else {
        resolve(false);
      }
    });

    server.once('listening', () => {
      server.close(() => resolve(true));
    });

    server.listen(port, host);
  });
}

async function getNextAvailablePort(startPort, host = '0.0.0.0', attempts = 10) {
  let candidate = startPort;

  for (let index = 0; index < attempts; index += 1) {
    if (await isPortAvailable(candidate, host)) {
      return candidate;
    }
    candidate += 1;
  }

  throw new Error(`Unable to find an available port near ${startPort}`);
}

async function listenWithFallback(app, startPort, host = '0.0.0.0', attempts = 10) {
  let candidate = startPort;

  for (let index = 0; index < attempts; index += 1) {
    const server = app();

    const result = await new Promise((resolve, reject) => {
      const onListening = () => {
        cleanup();
        resolve({ ok: true, port: candidate, server });
      };

      const onError = (error) => {
        cleanup();
        if (error && error.code === 'EADDRINUSE') {
          resolve({ ok: false, port: candidate, server });
          return;
        }

        reject(error);
      };

      const cleanup = () => {
        server.removeListener('listening', onListening);
        server.removeListener('error', onError);
      };

      server.once('listening', onListening);
      server.once('error', onError);
      server.listen(candidate, host);
    });

    if (result.ok) {
      return { server: result.server, port: result.port };
    }

    candidate += 1;
  }

  throw new Error(`Unable to find an available port near ${startPort}`);
}

module.exports = {
  getPortFromEnv,
  isPortAvailable,
  getNextAvailablePort,
  listenWithFallback,
};
