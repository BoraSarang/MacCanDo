// API 응답 공통 래퍼 (에러코드 + 로깅 규격)
// 모든 API: { ok, data?, error?: { code, message } }
import { NextResponse } from "next/server";
import errorMessages from "./error_message_ko.json";
import { logger } from "./logger";

export type ApiError = { code: string; message: string };

export function apiOk<T>(data: T, meta?: { method: string; path: string }) {
  if (meta) logger.apiResponse(meta.method, meta.path, 200, 0);
  return NextResponse.json({ ok: true, data });
}

export function apiError(
  code: string,
  status = 400,
  meta?: { method: string; path: string; ms?: number }
) {
  // 사용자 메시지 매핑 (error_message_ko.json)
  const message = errorMessages[code as keyof typeof errorMessages] ?? code;
  if (meta) {
    logger.error("API", `E: ${code}`, { method: meta.method, path: meta.path });
    logger.apiResponse(meta.method, meta.path, status, meta.ms ?? 0);
  }
  return NextResponse.json(
    { ok: false, error: { code, message } satisfies ApiError },
    { status }
  );
}

// API 핸들러 래퍼: try-catch + 로깅 공통화
export function withApi<C = unknown>(
  handler: (req: Request, ctx: C) => Promise<NextResponse>,
  feature: string
) {
  return async (req: Request, ctx: C) => {
    const method = req.method;
    const path = new URL(req.url).pathname;
    const start = performance.now();
    logger.apiRequest(method, path);
    logger.info("API", `${feature} 진입`, { method, path });
    try {
      const res = await handler(req, ctx);
      const ms = Math.round(performance.now() - start);
      logger.apiResponse(method, path, res.status, ms);
      if (ms > 300) logger.perf("API", `${feature} P95 초과 위험 (${ms}ms)`);
      return res;
    } catch (err) {
      const ms = Math.round(performance.now() - start);
      logger.error("API", `${feature} 실패: ${err instanceof Error ? err.message : err}`);
      return apiError("E-WEB-NET-1001", 500, { method, path, ms });
    }
  };
}