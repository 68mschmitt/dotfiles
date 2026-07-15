/**
 * Web Search Extension
 *
 * Replicates OpenCode's free web search using Exa and Parallel MCP endpoints.
 * No API keys required for basic usage. Optional keys for higher limits:
 *   - EXA_API_KEY
 *   - PARALLEL_API_KEY
 *
 * Provider selection:
 *   1. WEBSEARCH_PROVIDER=exa|parallel  (env override)
 *   2. Deterministic session hash        (stable per session)
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { createHash } from "node:crypto";

const EXA_URL = "https://mcp.exa.ai/mcp";
const PARALLEL_URL = "https://search.parallel.ai/mcp";
const MAX_RESPONSE_BYTES = 256 * 1024;
const TIMEOUT_MS = 25_000;
const NO_RESULTS = "No search results found. Please try a different query.";

type Provider = "exa" | "parallel";

function selectProvider(sessionId: string): Provider {
  const override = process.env.WEBSEARCH_PROVIDER;
  if (override === "exa" || override === "parallel") return override;
  const hash = createHash("md5").update(sessionId).digest("hex");
  return Number.parseInt(hash.slice(0, 8), 16) % 2 === 0 ? "exa" : "parallel";
}

function exaUrl(): string {
  const key = process.env.EXA_API_KEY;
  if (!key) return EXA_URL;
  const url = new URL(EXA_URL);
  url.searchParams.set("exaApiKey", key);
  return url.toString();
}

function parallelHeaders(): Record<string, string> {
  const headers: Record<string, string> = { "User-Agent": "pi-web-search/1.0" };
  const key = process.env.PARALLEL_API_KEY;
  if (key) headers["Authorization"] = `Bearer ${key}`;
  return headers;
}

interface McpResponse {
  result?: { content?: Array<{ type: string; text: string }> };
}

function parsePayload(payload: string): string | undefined {
  const trimmed = payload.trim();
  if (!trimmed.startsWith("{")) return undefined;
  try {
    const data = JSON.parse(trimmed) as McpResponse;
    return data.result?.content?.find((item) => item.text)?.text;
  } catch {
    return undefined;
  }
}

function parseResponse(body: string): string | undefined {
  // Try direct JSON-RPC response first
  const direct = parsePayload(body.trim());
  if (direct) return direct;

  // Fall back to SSE data: frames
  for (const line of body.split("\n")) {
    if (!line.startsWith("data: ")) continue;
    const data = parsePayload(line.substring(6));
    if (data) return data;
  }
  return undefined;
}

async function callMcp(
  url: string,
  toolName: string,
  args: Record<string, unknown>,
  signal: AbortSignal | undefined,
  extraHeaders: Record<string, string> = {},
): Promise<string> {
  const body = JSON.stringify({
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: { name: toolName, arguments: args },
  });

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);

  // Chain the caller's signal to our timeout controller
  if (signal) {
    signal.addEventListener("abort", () => controller.abort(), { once: true });
  }

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
        ...extraHeaders,
      },
      body,
      signal: controller.signal,
    });

    if (!res.ok) {
      throw new Error(`MCP ${toolName} returned ${res.status} ${res.statusText}`);
    }

    const text = await res.text();
    if (Buffer.byteLength(text, "utf8") > MAX_RESPONSE_BYTES) {
      throw new Error(`MCP ${toolName} response exceeded ${MAX_RESPONSE_BYTES} bytes`);
    }

    return parseResponse(text) ?? NO_RESULTS;
  } finally {
    clearTimeout(timeout);
  }
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description: [
      "Search the web for current information beyond knowledge cutoff.",
      "Performs real-time web searches via Exa or Parallel and returns content from the most relevant websites.",
      "",
      "Usage notes:",
      "  - Live crawl modes: 'fallback' (use cache first) or 'preferred' (prioritize live crawling)",
      "  - Search types: 'auto' (balanced), 'fast' (quick results), 'deep' (comprehensive)",
      "  - Configurable result count and context length",
      "",
      `The current year is ${new Date().getFullYear()}. Use this year when searching for recent information.`,
      `Example: If asked for "latest AI news", search for "AI news ${new Date().getFullYear()}".`,
    ].join("\n"),
    promptSnippet: "Search the web for up-to-date information beyond knowledge cutoff",
    promptGuidelines: [
      `Use web_search when the user asks about current events, recent releases, or information that may be beyond the knowledge cutoff. The current year is ${new Date().getFullYear()} — include the year in queries about recent topics.`,
    ],
    parameters: Type.Object({
      query: Type.String({ description: "Web search query" }),
      numResults: Type.Optional(
        Type.Integer({ description: "Number of results to return (default: 8, max: 20)", minimum: 1, maximum: 20 }),
      ),
      livecrawl: Type.Optional(
        Type.Union([Type.Literal("fallback"), Type.Literal("preferred")], {
          description:
            "Live crawl mode — 'fallback': use cached content first (default), 'preferred': prioritize live crawling",
        }),
      ),
      type: Type.Optional(
        Type.Union([Type.Literal("auto"), Type.Literal("fast"), Type.Literal("deep")], {
          description: "Search type — 'auto': balanced (default), 'fast': quick results, 'deep': comprehensive",
        }),
      ),
      contextMaxCharacters: Type.Optional(
        Type.Integer({
          description: "Maximum characters for context (default: 10000, max: 50000)",
          minimum: 1,
          maximum: 50000,
        }),
      ),
    }),

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const sessionId = ctx.sessionManager.getSessionId() ?? "default";
      const provider = selectProvider(sessionId);
      const providerLabel = provider === "exa" ? "Exa" : "Parallel";

      onUpdate?.({
        content: [{ type: "text", text: `Searching via ${providerLabel}: "${params.query}"...` }],
      });

      try {
        let result: string;

        if (provider === "exa") {
          result = await callMcp(
            exaUrl(),
            "web_search_exa",
            {
              query: params.query,
              type: params.type ?? "auto",
              numResults: params.numResults ?? 8,
              livecrawl: params.livecrawl ?? "fallback",
              ...(params.contextMaxCharacters ? { contextMaxCharacters: params.contextMaxCharacters } : {}),
            },
            signal,
          );
        } else {
          result = await callMcp(
            PARALLEL_URL,
            "web_search",
            {
              objective: params.query,
              search_queries: [params.query],
              session_id: sessionId,
            },
            signal,
            parallelHeaders(),
          );
        }

        return {
          content: [{ type: "text", text: result }],
          details: { provider: providerLabel, query: params.query },
        };
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        return {
          content: [{ type: "text", text: `Web search failed (${providerLabel}): ${message}` }],
          isError: true,
        };
      }
    },
  });
}
