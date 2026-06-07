import { HEALTH_METRICS, type CapabilityMatrix, type HealthMetric } from "./types.ts";
import { appleHealthWriteSupport } from "./normalize.ts";

export function createDefaultCapabilityMatrix(sourceId: string, readable: HealthMetric[]): CapabilityMatrix {
  const readableMap: CapabilityMatrix["readable"] = {};
  const writebackMap: CapabilityMatrix["appleHealthWriteback"] = {};

  for (const metric of HEALTH_METRICS) {
    readableMap[metric] = readable.includes(metric);
    writebackMap[metric] = appleHealthWriteSupport(metric);
  }

  return {
    sourceId,
    readable: readableMap,
    appleHealthWriteback: writebackMap,
    notes: [
      "HRV RMSSD is kept Passport-only until semantic mapping to Apple Health is explicitly confirmed."
    ]
  };
}
