import { appleHealthWriteSupport } from "./normalize.ts";
import { GOOGLE_HEALTH_SCOPES } from "./oauth.ts";
import type { HealthMetric, WriteSupport } from "./types.ts";

export type GoogleHealthImportStatus = "ready" | "deferred" | "blocked";

export interface GoogleHealthMetricImportPlan {
  metric: HealthMetric;
  googleDataTypeId?: string;
  requiredScope: string;
  dailyRollupValueField?: string;
  unit?: string;
  appleHealthWriteback: WriteSupport;
  status: GoogleHealthImportStatus;
  note: string;
}

export const GOOGLE_HEALTH_IMPORT_PLAN: GoogleHealthMetricImportPlan[] = [
  {
    metric: "steps",
    googleDataTypeId: "steps",
    requiredScope: GOOGLE_HEALTH_SCOPES.activityAndFitnessRead,
    dailyRollupValueField: "steps.countSum",
    unit: "count",
    appleHealthWriteback: appleHealthWriteSupport("steps"),
    status: "ready",
    note: "Daily rollup returns a whole-day step count."
  },
  {
    metric: "distance",
    googleDataTypeId: "distance",
    requiredScope: GOOGLE_HEALTH_SCOPES.activityAndFitnessRead,
    dailyRollupValueField: "distance.millimetersSum",
    unit: "m",
    appleHealthWriteback: appleHealthWriteSupport("distance"),
    status: "ready",
    note: "Daily rollup returns millimeters; Health Passport stores meters."
  },
  {
    metric: "active_energy",
    googleDataTypeId: "active-energy-burned",
    requiredScope: GOOGLE_HEALTH_SCOPES.activityAndFitnessRead,
    dailyRollupValueField: "activeEnergyBurned.kcalSum",
    unit: "kcal",
    appleHealthWriteback: appleHealthWriteSupport("active_energy"),
    status: "ready",
    note: "Daily rollup returns active energy in kilocalories."
  },
  {
    metric: "heart_rate",
    googleDataTypeId: "heart-rate",
    requiredScope: GOOGLE_HEALTH_SCOPES.healthMetricsRead,
    dailyRollupValueField: "heartRate.beatsPerMinuteAvg",
    unit: "count/min",
    appleHealthWriteback: appleHealthWriteSupport("heart_rate"),
    status: "ready",
    note: "Preview imports the daily average only; intraday samples stay deferred."
  },
  {
    metric: "resting_heart_rate",
    googleDataTypeId: "daily-resting-heart-rate",
    requiredScope: GOOGLE_HEALTH_SCOPES.healthMetricsRead,
    dailyRollupValueField: "restingHeartRatePersonalRange.beatsPerMinuteMin",
    unit: "count/min",
    appleHealthWriteback: appleHealthWriteSupport("resting_heart_rate"),
    status: "deferred",
    note: "Daily rollup exposes a personal range, not a clearly verified resting heart rate sample."
  },
  {
    metric: "sleep",
    requiredScope: GOOGLE_HEALTH_SCOPES.sleepRead,
    appleHealthWriteback: appleHealthWriteSupport("sleep"),
    status: "deferred",
    note: "Sleep is not in the dailyRollUp union; use dataPoints.list in a later slice."
  },
  {
    metric: "workout",
    requiredScope: GOOGLE_HEALTH_SCOPES.activityAndFitnessRead,
    appleHealthWriteback: appleHealthWriteSupport("workout"),
    status: "deferred",
    note: "Workout sessions need dedicated session mapping before import or writeback."
  },
  {
    metric: "hrv_rmssd",
    googleDataTypeId: "daily-heart-rate-variability",
    requiredScope: GOOGLE_HEALTH_SCOPES.healthMetricsRead,
    dailyRollupValueField: "heartRateVariabilityPersonalRange.averageHeartRateVariabilityMillisecondsMin",
    unit: "ms",
    appleHealthWriteback: appleHealthWriteSupport("hrv_rmssd"),
    status: "deferred",
    note: "HRV remains Passport-only until RMSSD/SDNN semantics and App Store wording are reviewed."
  }
];

export function googleHealthReadyDailyRollupMetrics(): GoogleHealthMetricImportPlan[] {
  return GOOGLE_HEALTH_IMPORT_PLAN.filter((plan) => plan.status === "ready" && !!plan.googleDataTypeId);
}
