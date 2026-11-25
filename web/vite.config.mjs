import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

function resolveSwStamp() {
  if (process.env.GITHUB_SHA) return process.env.GITHUB_SHA.slice(0, 7);
  try {
    return execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim();
  } catch {
    return Date.now().toString(36);
  }
}

function swCacheVersion() {
  let outDir = 'dist';
  return {
    name: 'sw-cache-version',
    configResolved(cfg) {
      outDir = cfg.build.outDir;
    },
    closeBundle() {
      const swPath = path.resolve(outDir, 'sw.js');
      if (!fs.existsSync(swPath)) return;
      const stamped = fs.readFileSync(swPath, 'utf8').replace("'shc-pwa-dev'", `'shc-pwa-${resolveSwStamp()}'`);
      fs.writeFileSync(swPath, stamped, 'utf8');
    },
  };
}

export default defineConfig({
  plugins: [react(), swCacheVersion()],
  base: './',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
});
