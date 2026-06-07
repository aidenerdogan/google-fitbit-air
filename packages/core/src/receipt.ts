import type { HealthMetric, SyncIssue, SyncReceipt } from "./types.ts";

export interface CreateReceiptInput {
  runId: string;
  sourceId: string;
  startedAt: string | Date;
  finishedAt: string | Date;
  imported: number;
  writtenToAppleHealth: number;
  skippedDuplicates?: number;
  gapsDetected?: number;
  unsupported?: HealthMetric[];
  errors?: SyncIssue[];
}

export function createSyncReceipt(input: CreateReceiptInput): SyncReceipt {
  if (input.imported < 0 || input.writtenToAppleHealth < 0) {
    throw new Error("Receipt counts cannot be negative");
  }

  const unsupported = Array.from(new Set(input.unsupported ?? [])).sort();

  return {
    runId: input.runId,
    sourceId: input.sourceId,
    startedAt: toIsoString(input.startedAt),
    finishedAt: toIsoString(input.finishedAt),
    imported: input.imported,
    writtenToAppleHealth: input.writtenToAppleHealth,
    skippedDuplicates: input.skippedDuplicates ?? 0,
    gapsDetected: input.gapsDetected ?? 0,
    unsupported,
    errors: input.errors ?? []
  };
}

function toIsoString(value: string | Date): string {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error("Invalid receipt date");
  }
  return date.toISOString();
}
