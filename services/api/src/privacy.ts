export interface PrivacyAuditEvent {
  route: string;
  accepted: boolean;
  rawHealthDataRejected: boolean;
  redactedFields: string[];
  topLevelKeys: string[];
  createdAt: string;
}

export interface CreatePrivacyAuditEventInput {
  route: string;
  body: unknown;
  createdAt: Date;
}

const RAW_HEALTH_DATA_KEYS = new Set([
  "samples",
  "rawSamples",
  "healthSamples",
  "heartRateSamples",
  "sleepSamples",
  "workoutSamples",
  "rawHealthData",
  "healthData",
  "intraday"
]);

export function containsRawHealthData(value: unknown): boolean {
  return findRawHealthDataPaths(value).length > 0;
}

export function createPrivacyAuditEvent(input: CreatePrivacyAuditEventInput): PrivacyAuditEvent {
  const redactedFields = findRawHealthDataPaths(input.body);

  return {
    route: input.route,
    accepted: redactedFields.length === 0,
    rawHealthDataRejected: redactedFields.length > 0,
    redactedFields,
    topLevelKeys: topLevelKeys(input.body),
    createdAt: input.createdAt.toISOString()
  };
}

export function findRawHealthDataPaths(value: unknown, path: string[] = []): string[] {
  if (value === null || typeof value !== "object") {
    return [];
  }

  if (Array.isArray(value)) {
    return value.flatMap((nested, index) => findRawHealthDataPaths(nested, [...path, String(index)]));
  }

  const record = value as Record<string, unknown>;
  return Object.entries(record).flatMap(([key, nested]) => {
    const currentPath = [...path, key];
    const nestedPaths = findRawHealthDataPaths(nested, currentPath);

    if (RAW_HEALTH_DATA_KEYS.has(key)) {
      return [currentPath.join("."), ...nestedPaths];
    }

    return nestedPaths;
  });
}

function topLevelKeys(value: unknown): string[] {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return [];
  }

  return Object.keys(value as Record<string, unknown>).sort();
}
