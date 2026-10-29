const test = require("node:test");
const assert = require("node:assert/strict");
const app = require("../server");

test("health endpoint returns healthy", async () => {
  const server = app.listen(0);

  try {
    const port = server.address().port;

    const response = await fetch(
      `http://127.0.0.1:${port}/health`
    );

    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.status, "healthy");
    assert.equal(body.service, "cloudops-platform");
  } finally {
    await new Promise((resolve, reject) => {
      server.close(error => {
        if (error) reject(error);
        else resolve();
      });
    });
  }
});

test("home page shows the current application", async () => {
  const server = app.listen(0);

  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/`);
    const body = await response.text();

    assert.equal(response.status, 200);
    assert.match(body, /CloudOps Platform/);
  } finally {
    await new Promise((resolve, reject) => {
      server.close(error => {
        if (error) reject(error);
        else resolve();
      });
    });
  }
});