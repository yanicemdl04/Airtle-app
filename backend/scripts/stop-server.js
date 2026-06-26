/**
 * Arrête le processus qui écoute sur un port (Windows).
 * Usage : node scripts/stop-server.js [3001]
 */
const { execSync } = require('child_process');

const ports = process.argv.slice(2).map(Number).filter(Boolean);
const targets = ports.length ? ports : [3001, 3002, 3000];

function killOnPort(port) {
  try {
    const out = execSync(`netstat -ano | findstr ":${port} "`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    const pids = new Set();
    for (const line of out.split('\n')) {
      if (!line.includes('LISTENING')) continue;
      const parts = line.trim().split(/\s+/);
      const pid = parts[parts.length - 1];
      if (/^\d+$/.test(pid)) pids.add(pid);
    }
    for (const pid of pids) {
      try {
        execSync(`taskkill /PID ${pid} /F`, { stdio: 'pipe' });
        // eslint-disable-next-line no-console
        console.log(`✓ Port ${port} libéré (PID ${pid})`);
      } catch {
        // eslint-disable-next-line no-console
        console.warn(`⚠ Impossible d'arrêter PID ${pid} sur le port ${port}`);
      }
    }
    if (pids.size === 0) {
      // eslint-disable-next-line no-console
      console.log(`· Port ${port} déjà libre`);
    }
  } catch {
    // eslint-disable-next-line no-console
    console.log(`· Port ${port} déjà libre`);
  }
}

for (const port of targets) {
  killOnPort(port);
}
