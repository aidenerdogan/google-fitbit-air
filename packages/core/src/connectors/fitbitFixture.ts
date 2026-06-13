import { createDefaultCapabilityMatrix } from "../capabilities.ts";
import { normalizeSample } from "../normalize.ts";
import type {
  AuthState,
  CapabilityMatrix,
  HealthMetric,
  NormalizedSample,
  SourceConnector,
  SyncBatch,
  SyncIssue,
  SyncRequest
} from "../types.ts";

export type FitbitFixtureScenario =
  | "success"
  | "expired_token"
  | "rate_limit"
  | "missing_metric"
  | "provider_outage";

export interface FitbitFixtureConnectorOptions {
  scenario?: FitbitFixtureScenario;
  importedAt?: string | Date;
}

const FITBIT_SOURCE_ID = "fitbit";
const FITBIT_PAYLOAD_VERSION = "fitbit-fixture-v1";
const FITBIT_READABLE_METRICS: HealthMetric[] = [
  "steps",
  "sleep",
  "heart_rate",
  "resting_heart_rate",
  "active_energy",
  "distance",
  "hrv_rmssd"
];

export class FitbitFixtureConnector implements SourceConnector {
  readonly id = FITBIT_SOURCE_ID;

  private readonly scenario: FitbitFixtureScenario;
  private readonly importedAt: string | Date;

  constructor(options: FitbitFixtureConnectorOptions = {}) {
    this.scenario = options.scenario ?? "success";
    this.importedAt = options.importedAt ?? "2026-06-13T12:00:00Z";
  }

  async authorize(): Promise<AuthState> {
    if (this.scenario === "expired_token") {
      return {
        providerId: this.id,
        status: "expired",
        scopes: []
      };
    }

    return {
      providerId: this.id,
      status: "authorized",
      scopes: ["activity", "heartrate", "sleep", "profile"],
      expiresAt: "2026-06-14T12:00:00Z"
    };
  }

  async getCapabilities(): Promise<CapabilityMatrix> {
    return createDefaultCapabilityMatrix(this.id, FITBIT_READABLE_METRICS);
  }

  async sync(request: SyncRequest): Promise<SyncBatch> {
    const scenarioIssue = issueForScenario(this.scenario);
    if (scenarioIssue && this.scenario !== "missing_metric") {
      return {
        sourceId: this.id,
        samples: [],
        issues: [scenarioIssue]
      };
    }

    const requestedMetrics = new Set(request.metrics ?? FITBIT_READABLE_METRICS);
    const samples = fitbitFixtureSamples(this.importedAt).filter((sample) => requestedMetrics.has(sample.metric));
    const issues = scenarioIssue ? [scenarioIssue] : [];

    return {
      sourceId: this.id,
      samples,
      issues
    };
  }
}

export function mapFitbitFixtureError(scenario: Exclude<FitbitFixtureScenario, "success">): SyncIssue {
  return issueForScenario(scenario) ?? {
    code: "fitbit_unknown",
    message: "Fitbit returned an unknown fixture error.",
    recoverable: true
  };
}

function fitbitFixtureSamples(importedAt: string | Date): NormalizedSample[] {
  const source = {
    provider: FITBIT_SOURCE_ID,
    deviceModel: "Fitbit Fixture",
    appName: "Health Passport"
  };

  return [
    normalizeSample({
      metric: "steps",
      startAt: "2026-06-13T07:00:00Z",
      endAt: "2026-06-13T08:00:00Z",
      value: 1280,
      source,
      externalId: "fitbit-fixture-steps-1",
      confidence: "high",
      importedAt,
      sourcePayloadVersion: FITBIT_PAYLOAD_VERSION
    }),
    normalizeSample({
      metric: "sleep",
      startAt: "2026-06-12T22:30:00Z",
      endAt: "2026-06-13T05:50:00Z",
      value: "asleep",
      source,
      externalId: "fitbit-fixture-sleep-1",
      confidence: "medium",
      importedAt,
      sourcePayloadVersion: FITBIT_PAYLOAD_VERSION
    }),
    normalizeSample({
      metric: "heart_rate",
      startAt: "2026-06-13T08:15:00Z",
      value: 72,
      source,
      externalId: "fitbit-fixture-hr-1",
      confidence: "high",
      importedAt,
      sourcePayloadVersion: FITBIT_PAYLOAD_VERSION
    }),
    normalizeSample({
      metric: "resting_heart_rate",
      startAt: "2026-06-13T06:00:00Z",
      value: 58,
      source,
      externalId: "fitbit-fixture-rhr-1",
      confidence: "medium",
      importedAt,
      sourcePayloadVersion: FITBIT_PAYLOAD_VERSION
    }),
    normalizeSample({
      metric: "active_energy",
      startAt: "2026-06-13T07:00:00Z",
      endAt: "2026-06-13T08:00:00Z",
      value: 86,
      source,
      externalId: "fitbit-fixture-energy-1",
      confidence: "high",
      importedAt,
      sourcePayloadVersion: FITBIT_PAYLOAD_VERSION
    }),
    normalizeSample({
      metric: "distance",
      startAt: "2026-06-13T07:00:00Z",
      endAt: "2026-06-13T08:00:00Z",
      value: 920,
      source,
      externalId: "fitbit-fixture-distance-1",
      confidence: "high",
      importedAt,
      sourcePayloadVersion: FITBIT_PAYLOAD_VERSION
    }),
    normalizeSample({
      metric: "hrv_rmssd",
      startAt: "2026-06-13T06:00:00Z",
      value: 44,
      source,
      externalId: "fitbit-fixture-hrv-rmssd-1",
      confidence: "low",
      importedAt,
      sourcePayloadVersion: FITBIT_PAYLOAD_VERSION
    })
  ];
}

function issueForScenario(scenario: FitbitFixtureScenario): SyncIssue | undefined {
  switch (scenario) {
    case "success":
      return undefined;
    case "expired_token":
      return {
        code: "fitbit_token_expired",
        message: "Fitbit authorization expired. The user needs to reconnect.",
        recoverable: true
      };
    case "rate_limit":
      return {
        code: "fitbit_rate_limited",
        message: "Fitbit rate limit reached. Sync should retry later.",
        recoverable: true
      };
    case "missing_metric":
      return {
        code: "fitbit_missing_metric",
        message: "Fitbit did not return one requested metric in the fixture response.",
        metric: "sleep",
        recoverable: true
      };
    case "provider_outage":
      return {
        code: "fitbit_provider_outage",
        message: "Fitbit fixture simulates a provider outage.",
        recoverable: true
      };
  }
}
