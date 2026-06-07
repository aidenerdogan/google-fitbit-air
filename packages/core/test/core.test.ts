import test from "node:test";
import assert from "node:assert/strict";

import {
  appleHealthWriteSupport,
  createDefaultCapabilityMatrix,
  createSyncReceipt,
  dedupeSamples,
  normalizeSample
} from "../src/index.ts";

test("normalizes a Fitbit steps sample with deterministic identity", () => {
  const sample = normalizeSample({
    metric: "steps",
    startAt: "2026-06-05T08:00:00+02:00",
    endAt: "2026-06-05T09:00:00+02:00",
    value: 1200,
    source: { provider: "fitbit", deviceModel: "Fitbit Air" },
    externalId: "activity-1",
    importedAt: "2026-06-05T10:00:00Z"
  });

  const duplicate = normalizeSample({
    metric: "steps",
    startAt: "2026-06-05T08:00:00+02:00",
    endAt: "2026-06-05T09:00:00+02:00",
    value: 1200,
    source: { provider: "fitbit", deviceModel: "Fitbit Air" },
    externalId: "activity-1",
    importedAt: "2026-06-05T10:05:00Z"
  });

  assert.equal(sample.id, duplicate.id);
  assert.equal(sample.unit, "count");
  assert.equal(sample.startAt, "2026-06-05T06:00:00.000Z");
  assert.equal(sample.provenance.sourceRecordId, "activity-1");
});

test("keeps RMSSD HRV Passport-only by default", () => {
  assert.equal(appleHealthWriteSupport("hrv_rmssd"), "unsupported");
  assert.equal(appleHealthWriteSupport("hrv_sdnn"), "supported");

  const matrix = createDefaultCapabilityMatrix("fitbit", ["steps", "hrv_rmssd"]);
  assert.equal(matrix.readable.hrv_rmssd, true);
  assert.equal(matrix.appleHealthWriteback.hrv_rmssd, "unsupported");
});

test("dedupes samples by provider metric and external id", () => {
  const first = normalizeSample({
    metric: "heart_rate",
    startAt: "2026-06-05T12:00:00Z",
    value: 72,
    source: { provider: "fitbit" },
    externalId: "hr-1"
  });

  const second = normalizeSample({
    metric: "heart_rate",
    startAt: "2026-06-05T12:01:00Z",
    value: 73,
    source: { provider: "fitbit" },
    externalId: "hr-1"
  });

  const result = dedupeSamples([first, second]);
  assert.equal(result.accepted.length, 1);
  assert.equal(result.duplicates.length, 1);
});

test("creates compact sync receipts with sorted unsupported metrics", () => {
  const receipt = createSyncReceipt({
    runId: "run-1",
    sourceId: "fitbit",
    startedAt: "2026-06-05T10:00:00Z",
    finishedAt: "2026-06-05T10:00:02Z",
    imported: 10,
    writtenToAppleHealth: 8,
    skippedDuplicates: 1,
    gapsDetected: 2,
    unsupported: ["hrv_rmssd", "sleep", "hrv_rmssd"],
    errors: []
  });

  assert.deepEqual(receipt.unsupported, ["hrv_rmssd", "sleep"]);
  assert.equal(receipt.skippedDuplicates, 1);
  assert.equal(receipt.gapsDetected, 2);
});
