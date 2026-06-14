import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { fileURLToPath } from "node:url";

import { reviewCoachResponse, wellnessCoachBoundary } from "../../../packages/core/src/coachSafety.ts";
import { containsRawHealthData, createPrivacyAuditEvent, type PrivacyAuditEvent } from "./privacy.ts";

export interface ApiOptions {
  region?: string;
  now?: () => Date;
  auditSink?: (event: PrivacyAuditEvent) => void;
}

export function createHealthPassportApi(options: ApiOptions = {}) {
  const region = options.region ?? "eu-first";
  const now = options.now ?? (() => new Date());
  const auditSink = options.auditSink ?? (() => undefined);

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
        const receivedAt = now();
        auditSink(
          createPrivacyAuditEvent({
            route: "/ai/context-packs",
            body,
            createdAt: receivedAt
          })
        );

        if (containsRawHealthData(body)) {
          return sendJson(response, 400, {
            error: "raw_health_data_rejected",
            message: "AI relay accepts approved summaries only, not raw health samples."
          });
        }

        if (!hasExplicitAiApproval(body)) {
          return sendJson(response, 403, {
            error: "ai_consent_required",
            message: "AI relay requires explicit user approval before accepting a context pack."
          });
        }

        const draftCoachResponse = extractDraftCoachResponse(body);
        if (draftCoachResponse) {
          const safety = reviewCoachResponse(draftCoachResponse);
          if (!safety.allowed) {
            return sendJson(response, 422, {
              error: "unsafe_coach_response_rejected",
              reason: safety.reason,
              matchedTerms: safety.matchedTerms,
              safeReply: safety.safeReply,
              boundary: wellnessCoachBoundary()
            });
          }
        }

        return sendJson(response, 202, {
          accepted: true,
          mode: "preview-relay-placeholder",
          coachBoundary: wellnessCoachBoundary(),
          receivedAt: receivedAt.toISOString()
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

function hasExplicitAiApproval(body: unknown): boolean {
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return false;
  }

  return (body as Record<string, unknown>).userApproved === true;
}

function extractDraftCoachResponse(body: unknown): string | undefined {
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return undefined;
  }

  const draftCoachResponse = (body as Record<string, unknown>).draftCoachResponse;
  return typeof draftCoachResponse === "string" && draftCoachResponse.trim().length > 0 ? draftCoachResponse : undefined;
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
