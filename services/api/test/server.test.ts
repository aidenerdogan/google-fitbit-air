import test from "node:test";
import assert from "node:assert/strict";

import { createHealthPassportApi } from "../src/server.ts";

test("health endpoint returns service status", async () => {
  const { baseUrl, close } = await startTestServer();
  try {
    const response = await fetch(`${baseUrl}/health`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.status, "ok");
    assert.equal(body.service, "health-passport-api");
  } finally {
    await close();
  }
});

test("privacy endpoint documents local-first backend boundaries", async () => {
  const { baseUrl, close } = await startTestServer();
  try {
    const response = await fetch(`${baseUrl}/privacy`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.rawHealthDataStored, false);
    assert.equal(body.backups, "client-encrypted-blobs-only");
    assert.equal(body.ai, "explicit-consent-context-packs-only");
  } finally {
    await close();
  }
});

test("AI relay rejects raw health samples", async () => {
  const { baseUrl, close } = await startTestServer();
  try {
    const response = await fetch(`${baseUrl}/ai/context-packs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        userApproved: true,
        samples: [{ metric: "heart_rate", value: 72 }]
      })
    });
    const body = await response.json();

    assert.equal(response.status, 400);
    assert.equal(body.error, "raw_health_data_rejected");
  } finally {
    await close();
  }
});

test("AI relay accepts summary context placeholders", async () => {
  const { baseUrl, close } = await startTestServer();
  try {
    const response = await fetch(`${baseUrl}/ai/context-packs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        userApproved: true,
        summary: "Sleep average dropped by 20 minutes this week.",
        gaps: ["No heart rate data on Tuesday."]
      })
    });
    const body = await response.json();

    assert.equal(response.status, 202);
    assert.equal(body.accepted, true);
  } finally {
    await close();
  }
});

async function startTestServer() {
  const server = createHealthPassportApi({
    now: () => new Date("2026-06-05T00:00:00Z")
  });

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  assert.equal(typeof address, "object");
  assert(address);

  return {
    baseUrl: `http://127.0.0.1:${address.port}`,
    close: () => new Promise<void>((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())))
  };
}
