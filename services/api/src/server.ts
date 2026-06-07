import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { fileURLToPath } from "node:url";

export interface ApiOptions {
  region?: string;
  now?: () => Date;
}

export function createHealthPassportApi(options: ApiOptions = {}) {
  const region = options.region ?? "eu-first";
  const now = options.now ?? (() => new Date());

  return createServer(async (request, response) => {
    try {
      if (request.method === "GET" && request.url === "/health") {
        return sendJson(response, 200, {
          status: "ok",
          service: "health-passport-api",
          checkedAt: now().toISOString()
        });
      }

      if (request.method === "GET" && request.url === "/privacy") {
        return sendJson(response, 200, {
          region,
          rawHealthDataStored: false,
          backups: "client-encrypted-blobs-only",
          ai: "explicit-consent-context-packs-only",
          ads: false
        });
      }

      if (request.method === "POST" && request.url === "/ai/context-packs") {
        const body = await readJson(request);
        if (containsRawHealthData(body)) {
          return sendJson(response, 400, {
            error: "raw_health_data_rejected",
            message: "AI relay accepts approved summaries only, not raw health samples."
          });
        }

        return sendJson(response, 202, {
          accepted: true,
          mode: "preview-relay-placeholder",
          receivedAt: now().toISOString()
        });
      }

      return sendJson(response, 404, { error: "not_found" });
    } catch (error) {
      return sendJson(response, 500, {
        error: "internal_error",
        message: error instanceof Error ? error.message : "Unknown error"
      });
    }
  });
}

function containsRawHealthData(value: unknown): boolean {
  if (value === null || typeof value !== "object") {
    return false;
  }

  if (Array.isArray(value)) {
    return value.some(containsRawHealthData);
  }

  const record = value as Record<string, unknown>;
  const suspiciousKeys = ["samples", "rawSamples", "healthSamples", "heartRateSamples", "sleepSamples"];

  return Object.entries(record).some(([key, nested]) => {
    if (suspiciousKeys.includes(key) && Array.isArray(nested)) {
      return true;
    }
    return containsRawHealthData(nested);
  });
}

async function readJson(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }

  if (chunks.length === 0) {
    return {};
  }

  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function sendJson(response: ServerResponse, statusCode: number, body: Record<string, unknown>) {
  response.writeHead(statusCode, { "content-type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(body));
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const port = Number(process.env.PORT ?? 4317);
  const server = createHealthPassportApi();
  server.listen(port, () => {
    console.log(`Health Passport API listening on http://127.0.0.1:${port}`);
  });
}
