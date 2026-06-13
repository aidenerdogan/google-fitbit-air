import type { HealthMetric, NormalizedSample } from "./types.ts";

export type GapStatus = "ready" | "gap" | "blocked";

export interface AnalyzeMetricGapsInput {
  samples: NormalizedSample[];
  metrics: HealthMetric[];
  startAt: string | Date;
  endAt: string | Date;
}

export interface MetricGapSummary {
  metric: HealthMetric;
  status: GapStatus;
  sampleCount: number;
  coveredDays: string[];
  missingDays: string[];
  firstSampleAt?: string;
  lastSampleAt?: string;
}

export interface GapAnalysis {
  windowStart: string;
  windowEnd: string;
  totalMissingDays: number;
  metrics: MetricGapSummary[];
}

const MS_PER_DAY = 86_400_000;

export function analyzeMetricGaps(input: AnalyzeMetricGapsInput): GapAnalysis {
  const windowStart = parseDate(input.startAt, "startAt");
  const windowEnd = parseDate(input.endAt, "endAt");
  if (windowEnd < windowStart) {
    throw new Error("Gap analysis endAt must be after startAt");
  }

  const days = enumerateUtcDays(windowStart, windowEnd);
  const metrics = input.metrics.map((metric) => {
    const metricSamples = input.samples
      .filter((sample) => sample.metric === metric)
      .sort((first, second) => new Date(first.startAt).getTime() - new Date(second.startAt).getTime());

    const coveredDays = days.filter((day) => metricSamples.some((sample) => sampleOverlapsUtcDay(sample, day)));
    const missingDays = days.filter((day) => !coveredDays.some((coveredDay) => coveredDay.label === day.label));
    const status = statusFor(metricSamples.length, missingDays.length);
    const firstSample = metricSamples[0];
    const lastSample = metricSamples[metricSamples.length - 1];

    return {
      metric,
      status,
      sampleCount: metricSamples.length,
      coveredDays: coveredDays.map((day) => day.label),
      missingDays: missingDays.map((day) => day.label),
      firstSampleAt: firstSample?.startAt,
      lastSampleAt: lastSample?.endAt ?? lastSample?.startAt
    };
  });

  return {
    windowStart: windowStart.toISOString(),
    windowEnd: windowEnd.toISOString(),
    totalMissingDays: metrics.reduce((total, metric) => total + metric.missingDays.length, 0),
    metrics
  };
}

function statusFor(sampleCount: number, missingDayCount: number): GapStatus {
  if (sampleCount === 0) {
    return "blocked";
  }

  return missingDayCount > 0 ? "gap" : "ready";
}

function enumerateUtcDays(start: Date, end: Date): Array<{ label: string; start: Date; end: Date }> {
  const cursor = utcDayStart(start);
  const finalDay = utcDayStart(end);
  const days: Array<{ label: string; start: Date; end: Date }> = [];

  while (cursor <= finalDay) {
    days.push({
      label: cursor.toISOString().slice(0, 10),
      start: new Date(cursor),
      end: new Date(cursor.getTime() + MS_PER_DAY - 1)
    });
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }

  return days;
}

function sampleOverlapsUtcDay(sample: NormalizedSample, day: { start: Date; end: Date }): boolean {
  const sampleStart = parseDate(sample.startAt, "sample.startAt");
  const sampleEnd = sample.endAt ? parseDate(sample.endAt, "sample.endAt") : sampleStart;
  return sampleStart <= day.end && sampleEnd >= day.start;
}

function utcDayStart(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function parseDate(value: string | Date, field: string): Date {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid gap analysis date: ${field}`);
  }
  return date;
}
