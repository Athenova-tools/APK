/* Browser regression test: APK Index must discover ISTQB releases beyond page 1. */
'use strict';

const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');

function loadPlaywright() {
  const candidates = [];
  for (const name of ['playwright', 'playwright-core']) {
    try { candidates.push(path.dirname(require.resolve(name + '/package.json'))); } catch (error) {}
  }
  try {
    const npx = path.join(os.homedir(), '.npm', '_npx');
    for (const entry of fs.readdirSync(npx)) {
      for (const name of ['playwright', 'playwright-core']) {
        const dir = path.join(npx, entry, 'node_modules', name);
        if (fs.existsSync(path.join(dir, 'package.json'))) candidates.push(dir);
      }
    }
  } catch (error) {}
  for (const dir of candidates) {
    try {
      const playwright = require(dir);
      if (playwright.chromium) return playwright;
    } catch (error) {}
  }
  throw new Error('Playwright is unavailable; install it or populate the npx cache.');
}

function startServer(root) {
  const server = http.createServer((request, response) => {
    const file = path.join(root, new URL(request.url, 'http://localhost').pathname);
    try {
      response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      response.end(fs.readFileSync(file));
    } catch (error) {
      response.writeHead(404);
      response.end('not found');
    }
  });
  return new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server)));
}

function release(tag, asset, publishedAt) {
  return {
    tag_name: tag,
    name: tag,
    draft: false,
    prerelease: false,
    published_at: publishedAt,
    assets: [{
      name: asset,
      browser_download_url: 'https://downloads.example/' + asset,
      size: 1024,
      created_at: publishedAt,
    }],
  };
}

(async function main() {
  const playwright = loadPlaywright();
  const root = path.join(__dirname, '..');
  const suppliedBase = process.argv[2];
  const server = suppliedBase ? null : await startServer(root);
  const base = (suppliedBase || ('http://127.0.0.1:' + server.address().port)).replace(/\/+$/, '');
  const browser = await playwright.chromium.launch();
  const page = await browser.newPage();
  let requestedPages = [];

  if (suppliedBase) {
    page.on('request', request => {
      if (!request.url().startsWith('https://api.github.com/repos/Athenova-tools/APK/releases?')) return;
      requestedPages.push(Number(new URL(request.url()).searchParams.get('page')));
    });
  } else {
    await page.route('https://api.github.com/repos/Athenova-tools/APK/releases?*', async route => {
      const url = new URL(route.request().url());
      const pageNumber = Number(url.searchParams.get('page'));
      requestedPages.push(pageNumber);
      const releases = pageNumber === 1
        ? Array.from({ length: 100 }, (_, index) => release(
          'stock-release-v1.0-' + index, 'stock-release.apk', '2026-11-10T00:00:00Z'))
        : [
          release('istqb-release-v4.0.1-20261113T175551Z-295322', 'istqb-release.apk', '2026-11-13T17:55:58Z'),
          release('istqb-debug-v4.0.1-20261113T175542Z-295213', 'istqb-debug.apk', '2026-11-13T17:55:50Z'),
        ];
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(releases) });
    });
  }

  try {
    await page.goto(base + '/index.html', { waitUntil: 'load' });
    try {
      await page.waitForFunction(() => {
        const grid = document.querySelector('[data-app="istqb"]');
        return grid && grid.querySelectorAll('.version-number').length >= 2 && !grid.querySelector('.empty-state');
      }, null, { timeout: 45000 });
    } catch (error) {
      const diagnostics = await page.evaluate(() => ({
        status: document.getElementById('status') && document.getElementById('status').textContent,
        istqb: document.querySelector('[data-app="istqb"]') && document.querySelector('[data-app="istqb"]').innerText,
      }));
      throw new Error(error.message + ' | requests=' + JSON.stringify(requestedPages) +
        ' | page=' + JSON.stringify(diagnostics));
    }
    const state = await page.evaluate(() => {
      const grid = document.querySelector('[data-app="istqb"]');
      return {
        versions: Array.from(grid.querySelectorAll('.version-number')).map(node => node.textContent),
        downloads: Array.from(grid.querySelectorAll('a.download')).map(node => node.href),
        emptyState: !!grid.querySelector('.empty-state'),
      };
    });

    if ((!suppliedBase && JSON.stringify(requestedPages) !== JSON.stringify([1, 2])) ||
        (suppliedBase && (!requestedPages.includes(1) || !requestedPages.includes(2)))) {
      throw new Error('Expected GitHub release pages [1, 2], got ' + JSON.stringify(requestedPages));
    }
    if (state.emptyState || state.versions.filter(version => version === 'v4.0.1').length < 2) {
      throw new Error('ISTQB release/debug cards were not populated: ' + JSON.stringify(state));
    }
    if (!state.downloads.some(url => url.endsWith('/istqb-release.apk')) ||
        !state.downloads.some(url => url.endsWith('/istqb-debug.apk'))) {
      throw new Error('Expected downloadable ISTQB release and debug APK links: ' + JSON.stringify(state.downloads));
    }
    console.log('PASS  APK Index paginates GitHub releases and displays ISTQB release + debug APKs.');
  } finally {
    await browser.close();
    if (server) server.close();
  }
})().catch(error => {
  console.error('FAIL ', error.message);
  process.exit(1);
});
