import type { HealthMetric } from "./types.ts";

export type OAuthProviderId = "google_health" | "fitbit_web_api_legacy";
export type OAuthFlow = "authorization_code_pkce";
export type TokenStorageLocation = "device_secure_store" | "backend_encrypted_broker";

export interface OAuthTokenSet {
  providerId: OAuthProviderId;
  accessToken: string;
  refreshToken?: string;
  tokenType: "Bearer";
  expiresAt: string;
  scopes: string[];
}

export interface OAuthTokenStore {
  save(tokens: OAuthTokenSet): Promise<void>;
  load(providerId: OAuthProviderId): Promise<OAuthTokenSet | undefined>;
  delete(providerId: OAuthProviderId): Promise<void>;
}

export interface OAuthScopePlan {
  providerId: OAuthProviderId;
  flow: OAuthFlow;
  scopes: string[];
  tokenStorage: TokenStorageLocation;
  requiresClientSecret: boolean;
  notes: string[];
}

export const GOOGLE_HEALTH_SCOPES = {
  activityAndFitnessRead: "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
  healthMetricsRead: "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
  profileRead: "https://www.googleapis.com/auth/googlehealth.profile.readonly",
  sleepRead: "https://www.googleapis.com/auth/googlehealth.sleep.readonly"
} as const;

export const FITBIT_WEB_API_LEGACY_SCOPES = {
  activity: "activity",
  heartrate: "heartrate",
  profile: "profile",
  sleep: "sleep"
} as const;

export const MVP_IMPORT_METRICS: HealthMetric[] = [
  "steps",
  "workout",
  "sleep",
  "heart_rate",
  "resting_heart_rate",
  "active_energy",
  "distance",
  "hrv_rmssd"
];

export function googleHealthScopesForMetrics(metrics: HealthMetric[], includeProfile = true): string[] {
  const scopes = new Set<string>();

  for (const metric of metrics) {
    for (const scope of googleHealthScopesForMetric(metric)) {
      scopes.add(scope);
    }
  }

  if (includeProfile) {
    scopes.add(GOOGLE_HEALTH_SCOPES.profileRead);
  }

  return Array.from(scopes).sort();
}

export function fitbitLegacyScopesForMetrics(metrics: HealthMetric[], includeProfile = true): string[] {
  const scopes = new Set<string>();

  for (const metric of metrics) {
    for (const scope of fitbitLegacyScopesForMetric(metric)) {
      scopes.add(scope);
    }
  }

  if (includeProfile) {
    scopes.add(FITBIT_WEB_API_LEGACY_SCOPES.profile);
  }

  return Array.from(scopes).sort();
}

export function createMvpOAuthScopePlans(tokenStorage: TokenStorageLocation = "device_secure_store"): OAuthScopePlan[] {
  return [
    {
      providerId: "google_health",
      flow: "authorization_code_pkce",
      scopes: googleHealthScopesForMetrics(MVP_IMPORT_METRICS),
      tokenStorage,
      requiresClientSecret: false,
      notes: [
        "Preferred cloud path for Fitbit/Google device data.",
        "Request read-only scopes first; writeback remains Apple Health-only in the iOS MVP.",
        "Add more scopes later only after a product screen needs them."
      ]
    },
    {
      providerId: "fitbit_web_api_legacy",
      flow: "authorization_code_pkce",
      scopes: fitbitLegacyScopesForMetrics(MVP_IMPORT_METRICS),
      tokenStorage,
      requiresClientSecret: false,
      notes: [
        "Legacy fallback while migration access is being confirmed.",
        "Do not use client credentials for user data.",
        "Keep token handling behind the same token store contract."
      ]
    }
  ];
}

function googleHealthScopesForMetric(metric: HealthMetric): string[] {
  switch (metric) {
    case "steps":
    case "workout":
    case "active_energy":
    case "distance":
      return [GOOGLE_HEALTH_SCOPES.activityAndFitnessRead];
    case "heart_rate":
    case "resting_heart_rate":
    case "hrv_sdnn":
    case "hrv_rmssd":
      return [GOOGLE_HEALTH_SCOPES.healthMetricsRead];
    case "sleep":
      return [GOOGLE_HEALTH_SCOPES.sleepRead];
  }
}

function fitbitLegacyScopesForMetric(metric: HealthMetric): string[] {
  switch (metric) {
    case "steps":
    case "workout":
    case "active_energy":
    case "distance":
      return [FITBIT_WEB_API_LEGACY_SCOPES.activity];
    case "heart_rate":
    case "resting_heart_rate":
    case "hrv_sdnn":
    case "hrv_rmssd":
      return [FITBIT_WEB_API_LEGACY_SCOPES.heartrate];
    case "sleep":
      return [FITBIT_WEB_API_LEGACY_SCOPES.sleep];
  }
}
