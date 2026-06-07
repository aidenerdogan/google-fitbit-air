import { HEALTH_METRICS, type CreateSampleInput, type HealthMetric, type NormalizedSample } from "./types.ts";

const metricDefaults: Record<HealthMetric, { unit?: string; appleHealthWriteback: "supported" | "unsupported" | "requires_review" }> = {
  steps: { unit: "count", appleHealthWriteback: "supported" },
  workout: { appleHealthWriteback: "supported" },
  sleep: { appleHealthWriteback: "supported" },
  heart_rate: { unit: "count/min", appleHealthWriteback: "supported" },
  resting_heart_rate: { unit: "count/min", appleHealthWriteback: "supported" },
  active_energy: { unit: "kcal", appleHealthWriteback: "supported" },
  distance: { unit: "m", appleHealthWriteback: "supported" },
  hrv_sdnn: { unit: "ms", appleHealthWriteback: "supported" },
  hrv_rmssd: { unit: "ms", appleHealthWriteback: "unsupported" }
};

export function isHealthMetric(metric: string): metric is HealthMetric {
  return (HEALTH_METRICS as readonly string[]).includes(metric);
}

export function appleHealthWriteSupport(metric: HealthMetric): "supported" | "unsupported" | "requires_review" {
  return metricDefaults[metric].appleHealthWriteback;
}

export function defaultUnitForMetric(metric: HealthMetric): string | undefined {
  return metricDefaults[metric].unit;
}

export function normalizeSample(input: CreateSampleInput): NormalizedSample {
  if (!isHealthMetric(input.metric)) {
    throw new Error(`Unsupported metric: ${String(input.metric)}`);
  }

  if (!input.source.provider.trim()) {
    throw new Error("Sample source provider is required");
  }

  const startAt = toIsoString(input.startAt, "startAt");
  const endAt = input.endAt === undefined ? undefined : toIsoString(input.endAt, "endAt");
  const importedAt = toIsoString(input.importedAt ?? new Date(), "importedAt");

  if (endAt && Date.parse(endAt) < Date.parse(startAt)) {
    throw new Error("Sample endAt cannot be earlier than startAt");
  }

  const id = createSampleId({
    metric: input.metric,
    startAt,
    endAt,
    value: input.value,
    sourceProvider: input.source.provider,
    externalId: input.externalId
  });

  return {
    id,
    metric: input.metric,
    startAt,
    endAt,
    value: input.value,
    unit: input.unit ?? defaultUnitForMetric(input.metric),
    source: input.source,
    externalId: input.externalId,
    confidence: input.confidence ?? "medium",
    provenance: {
      importedAt,
      sourceRecordId: input.externalId,
      sourcePayloadVersion: input.sourcePayloadVersion
    }
  };
}

function toIsoString(value: string | Date, field: string): string {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid ${field} date`);
  }
  return date.toISOString();
}

function createSampleId(input: Record<string, unknown>): string {
  return `hp_${fnv1a(stableStringify(input))}`;
}

function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }

  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }

  const record = value as Record<string, unknown>;
  return `{${Object.keys(record)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${stableStringify(record[key])}`)
    .join(",")}}`;
}

function fnv1a(input: string): string {
  let hash = 0x811c9dc5;
  for (let index = 0; index < input.length; index += 1) {
    hash ^= input.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}
