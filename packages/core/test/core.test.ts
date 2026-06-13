import test from "node:test";
import assert from "node:assert/strict";

import {
  appleHealthWriteSupport,
  analyzeMetricGaps,
  createMvpOAuthScopePlans,
  createDefaultCapabilityMatrix,
  fitbitLegacyScopesForMetrics,
  googleHealthScopesForMetrics,
  GOOGLE_HEALTH_SCOPES,
  createSyncReceipt,
  dedupeSamplesAgainstExisting,
  dedupeSamples,
  FitbitFixtureConnector,
  mapFitbitFixtureError,
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

test("imports Fitbit fixture samples through the connector boundary", async () => {
  const connector = new FitbitFixtureConnector({ importedAt: "2026-06-13T12:00:00Z" });
  const auth = await connector.authorize();
  const capabilities = await connector.getCapabilities();
  const batch = await connector.sync({ sourceId: "fitbit", metrics: ["steps", "sleep", "hrv_rmssd"] });

  assert.equal(auth.status, "authorized");
  assert.equal(capabilities.readable.steps, true);
  assert.equal(capabilities.appleHealthWriteback.hrv_rmssd, "unsupported");
  assert.equal(batch.sourceId, "fitbit");
  assert.equal(batch.samples.length, 3);
  assert.deepEqual(
    batch.samples.map((sample) => sample.metric).sort(),
    ["hrv_rmssd", "sleep", "steps"]
  );
  assert.equal(batch.samples[0].source.provider, "fitbit");
  assert.equal(batch.issues.length, 0);
});

test("maps Fitbit fixture connector error scenarios", async () => {
  const expired = new FitbitFixtureConnector({ scenario: "expired_token" });
  const expiredAuth = await expired.authorize();
  const expiredBatch = await expired.sync({ sourceId: "fitbit" });

  assert.equal(expiredAuth.status, "expired");
  assert.equal(expiredBatch.samples.length, 0);
  assert.equal(expiredBatch.issues[0]?.code, "fitbit_token_expired");

  const rateLimit = mapFitbitFixtureError("rate_limit");
  const providerOutage = mapFitbitFixtureError("provider_outage");
  const missingMetric = new FitbitFixtureConnector({ scenario: "missing_metric" });
  const missingMetricBatch = await missingMetric.sync({ sourceId: "fitbit" });

  assert.equal(rateLimit.code, "fitbit_rate_limited");
  assert.equal(providerOutage.code, "fitbit_provider_outage");
  assert.equal(missingMetricBatch.samples.length > 0, true);
  assert.equal(missingMetricBatch.issues[0]?.code, "fitbit_missing_metric");
  assert.equal(missingMetricBatch.issues[0]?.metric, "sleep");
});

test("dedupes Fitbit fixture imports against existing vault samples", async () => {
  const connector = new FitbitFixtureConnector({ importedAt: "2026-06-13T12:00:00Z" });
  const firstBatch = await connector.sync({ sourceId: "fitbit" });
  const secondBatch = await connector.sync({ sourceId: "fitbit" });
  const result = dedupeSamplesAgainstExisting(firstBatch.samples, secondBatch.samples);

  assert.equal(firstBatch.samples.length, 7);
  assert.equal(result.accepted.length, 0);
  assert.equal(result.duplicates.length, 7);
});

test("detects missing metric days in a local analysis window", () => {
  const stepsFirstDay = normalizeSample({
    metric: "steps",
    startAt: "2026-06-13T07:00:00Z",
    endAt: "2026-06-13T08:00:00Z",
    value: 1280,
    source: { provider: "fitbit" },
    externalId: "steps-day-1"
  });
  const stepsSecondDay = normalizeSample({
    metric: "steps",
    startAt: "2026-06-14T07:00:00Z",
    endAt: "2026-06-14T08:00:00Z",
    value: 1320,
    source: { provider: "fitbit" },
    externalId: "steps-day-2"
  });
  const sleepFirstDay = normalizeSample({
    metric: "sleep",
    startAt: "2026-06-12T22:00:00Z",
    endAt: "2026-06-13T05:30:00Z",
    value: "asleep",
    source: { provider: "fitbit" },
    externalId: "sleep-day-1"
  });

  const analysis = analyzeMetricGaps({
    samples: [stepsFirstDay, stepsSecondDay, sleepFirstDay],
    metrics: ["steps", "sleep", "workout"],
    startAt: "2026-06-13T00:00:00Z",
    endAt: "2026-06-14T23:59:00Z"
  });

  assert.equal(analysis.totalMissingDays, 3);
  assert.equal(analysis.metrics.find((metric) => metric.metric === "steps")?.status, "ready");
  assert.deepEqual(analysis.metrics.find((metric) => metric.metric === "sleep")?.missingDays, ["2026-06-14"]);
  assert.deepEqual(analysis.metrics.find((metric) => metric.metric === "workout")?.missingDays, [
    "2026-06-13",
    "2026-06-14"
  ]);
});

test("plans Google Health read scopes for MVP import metrics", () => {
  const scopes = googleHealthScopesForMetrics(["steps", "sleep", "heart_rate", "distance"]);

  assert.deepEqual(scopes, [
    GOOGLE_HEALTH_SCOPES.activityAndFitnessRead,
    GOOGLE_HEALTH_SCOPES.healthMetricsRead,
    GOOGLE_HEALTH_SCOPES.profileRead,
    GOOGLE_HEALTH_SCOPES.sleepRead
  ]);
  assert.equal(scopes.some((scope) => scope.includes(".write")), false);
});

test("keeps legacy Fitbit scopes separate from Google Health scopes", () => {
  assert.deepEqual(fitbitLegacyScopesForMetrics(["steps", "sleep", "heart_rate"]), [
    "activity",
    "heartrate",
    "profile",
    "sleep"
  ]);

  const plans = createMvpOAuthScopePlans();
  assert.equal(plans[0]?.providerId, "google_health");
  assert.equal(plans[0]?.flow, "authorization_code_pkce");
  assert.equal(plans[0]?.requiresClientSecret, false);
  assert.equal(plans[1]?.providerId, "fitbit_web_api_legacy");
});
