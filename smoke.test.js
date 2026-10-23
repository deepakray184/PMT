'use strict';

const { after, before, test } = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('./server');

const server = createServer();
let baseUrl;

before(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
});

test('serves the project workspace and its application assets', async () => {
  const [home, script, styles] = await Promise.all([
    fetch(baseUrl), fetch(`${baseUrl}/script.js`), fetch(`${baseUrl}/styles.css`),
  ]);
  assert.equal(home.status, 200);
  assert.match(home.headers.get('content-type'), /text\/html/);
  assert.match(await home.text(), /id="projectForm"/);
  assert.equal(script.status, 200);
  assert.match(script.headers.get('content-type'), /javascript/);
  assert.match(await script.text(), /projectKey/);
  assert.equal(styles.status, 200);
  assert.match(styles.headers.get('content-type'), /text\/css/);
});

test('rejects unsafe paths and unsupported methods', async () => {
  const traversal = await fetch(`${baseUrl}/%2e%2e%2fserver.js`);
  const unsupported = await fetch(baseUrl, { method: 'POST' });
  assert.ok([400, 403, 404].includes(traversal.status));
  assert.equal(unsupported.status, 405);
});
