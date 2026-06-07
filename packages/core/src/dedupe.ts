import type { NormalizedSample } from "./types.ts";

export interface DedupeResult {
  accepted: NormalizedSample[];
  duplicates: NormalizedSample[];
}

export function dedupeSamples(samples: NormalizedSample[]): DedupeResult {
  const seen = new Set<string>();
  const accepted: NormalizedSample[] = [];
  const duplicates: NormalizedSample[] = [];

  for (const sample of samples) {
    const key = sample.externalId
      ? `${sample.source.provider}:${sample.metric}:${sample.externalId}`
      : `${sample.source.provider}:${sample.metric}:${sample.startAt}:${sample.endAt ?? ""}:${JSON.stringify(sample.value)}`;

    if (seen.has(key)) {
      duplicates.push(sample);
      continue;
    }

    seen.add(key);
    accepted.push(sample);
  }

  return { accepted, duplicates };
}
