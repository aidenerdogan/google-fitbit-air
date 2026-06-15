import { normalizeSample } from "./normalize.ts";
import { GOOGLE_HEALTH_IMPORT_PLAN, type GoogleHealthMetricImportPlan } from "./googleHealthImportPlan.ts";
import type { HealthMetric, NormalizedSample } from "./types.ts";

export interface GoogleHealthCivilDate {
  year: number;
  month: number;
  day: number;
}

export interface GoogleHealthDailyRollupPoint {
  civilStartTime: { date: GoogleHealthCivilDate };
  civilEndTime: { date: GoogleHealthCivilDate };
  steps?: { countSum?: string };
  distance?: { millimetersSum?: string };
  activeEnergyBurned?: { kcalSum?: number };
  heartRate?: { beatsPerMinuteAvg?: number };
  restingHeartRatePersonalRange?: { beatsPerMinuteMin?: number };
}

export interface GoogleHealthDailyRollupResponse {
  rollupDataPoints: GoogleHealthDailyRollupPoint[];
}

export interface GoogleHealthRollupDecodeInput {
  metric: HealthMetric;
  response: GoogleHealthDailyRollupResponse;
  importedAt: string | Date;
}

export function decodeGoogleHealthDailyRollup(input: GoogleHealthRollupDecodeInput): NormalizedSample[] {
  const plan = GOOGLE_HEALTH_IMPORT_PLAN.find((candidate) => candidate.metric === input.metric);
  if (!plan || plan.status !== "ready" || !plan.googleDataTypeId) {
    return [];
  }

  return input.response.rollupDataPoints.flatMap((point) => {
    const value = valueForPoint(plan, point);
    if (value === undefined) {
      return [];
    }

    const startAt = civilDateToIso(point.civilStartTime.date);
    const endAt = civilDateToIso(point.civilEndTime.date);
    const dateId = civilDateId(point.civilStartTime.date);

    return normalizeSample({
      metric: plan.metric,
      startAt,
      endAt,
      value,
      unit: plan.unit,
      source: {
        provider: "google_health",
        deviceModel: "Google wearable",
        appName: "Google Health"
      },
      externalId: `google-health:daily-rollup:${plan.googleDataTypeId}:${dateId}`,
      confidence: "medium",
      importedAt: input.importedAt,
      sourcePayloadVersion: "google-health-daily-rollup-v1"
    });
  });
}

function valueForPoint(plan: GoogleHealthMetricImportPlan, point: GoogleHealthDailyRollupPoint): number | undefined {
  switch (plan.metric) {
    case "steps":
      return parseNumber(point.steps?.countSum);
    case "distance": {
      const millimeters = parseNumber(point.distance?.millimetersSum);
      return millimeters === undefined ? undefined : millimeters / 1000;
    }
    case "active_energy":
      return point.activeEnergyBurned?.kcalSum;
    case "heart_rate":
      return point.heartRate?.beatsPerMinuteAvg;
    case "resting_heart_rate":
      return point.restingHeartRatePersonalRange?.beatsPerMinuteMin;
    default:
      return undefined;
  }
}

function parseNumber(value: string | undefined): number | undefined {
  if (value === undefined) {
    return undefined;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function civilDateToIso(date: GoogleHealthCivilDate): string {
  return new Date(Date.UTC(date.year, date.month - 1, date.day)).toISOString();
}

function civilDateId(date: GoogleHealthCivilDate): string {
  return `${date.year}-${String(date.month).padStart(2, "0")}-${String(date.day).padStart(2, "0")}`;
}

