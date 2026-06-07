export const HEALTH_METRICS = [
  "steps",
  "workout",
  "sleep",
  "heart_rate",
  "resting_heart_rate",
  "active_energy",
  "distance",
  "hrv_sdnn",
  "hrv_rmssd"
] as const;

export type HealthMetric = (typeof HEALTH_METRICS)[number];

export type Confidence = "high" | "medium" | "low";

export type WriteSupport = "supported" | "unsupported" | "requires_review";

export interface AuthState {
  providerId: string;
  status: "authorized" | "expired" | "revoked" | "not_authorized";
  scopes: string[];
  expiresAt?: string;
}

export interface CapabilityMatrix {
  sourceId: string;
  readable: Partial<Record<HealthMetric, boolean>>;
  appleHealthWriteback: Partial<Record<HealthMetric, WriteSupport>>;
  notes: string[];
}

export interface SyncRequest {
  sourceId: string;
  since?: string;
  until?: string;
  metrics?: HealthMetric[];
}

export interface DataSourceRef {
  provider: string;
  deviceModel?: string;
  appName?: string;
}

export interface Provenance {
  importedAt: string;
  sourceRecordId?: string;
  sourcePayloadVersion?: string;
}

export interface NormalizedSample {
  id: string;
  metric: HealthMetric;
  startAt: string;
  endAt?: string;
  value: number | string | Record<string, unknown>;
  unit?: string;
  source: DataSourceRef;
  externalId?: string;
  confidence: Confidence;
  provenance: Provenance;
}

export interface CreateSampleInput {
  metric: HealthMetric;
  startAt: string | Date;
  endAt?: string | Date;
  value: number | string | Record<string, unknown>;
  unit?: string;
  source: DataSourceRef;
  externalId?: string;
  confidence?: Confidence;
  importedAt?: string | Date;
  sourcePayloadVersion?: string;
}

export interface SyncIssue {
  code: string;
  message: string;
  metric?: HealthMetric;
  sourceRecordId?: string;
  recoverable: boolean;
}

export interface SyncBatch {
  sourceId: string;
  samples: NormalizedSample[];
  issues: SyncIssue[];
}

export interface SyncReceipt {
  runId: string;
  sourceId: string;
  startedAt: string;
  finishedAt: string;
  imported: number;
  writtenToAppleHealth: number;
  skippedDuplicates: number;
  gapsDetected: number;
  unsupported: HealthMetric[];
  errors: SyncIssue[];
}

export interface SourceConnector {
  id: string;
  authorize(): Promise<AuthState>;
  getCapabilities(): Promise<CapabilityMatrix>;
  sync(request: SyncRequest): Promise<SyncBatch>;
}
