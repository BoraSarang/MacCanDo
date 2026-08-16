// [FEATURE] 관리자 API 토큰 — T-06
// macOS 앱 인증용: 관리자 세션에서 토큰 발급, Bearer 헤더로 API 호출
// JWT (HS256, AUTH_SECRET 서명), 만료 30일
import { SignJWT, jwtVerify } from "jose";
import { logger } from "./logger";

const secret = new TextEncoder().encode(process.env.AUTH_SECRET ?? "");
const TOKEN_TYPE = "api";
const TOKEN_TTL = "30d";

export interface ApiTokenPayload {
  sub: string;
  role: string;
  type: string;
}

// 관리자 API 토큰 발급
export async function issueApiToken(input: { userId: string; role: string }): Promise<string> {
  const token = await new SignJWT({ role: input.role, type: TOKEN_TYPE })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(input.userId)
    .setIssuedAt()
    .setExpirationTime(TOKEN_TTL)
    .sign(secret);
  logger.info("Auth", `API 토큰 발급 (user=${input.userId})`);
  return token;
}

// Bearer 토큰 검증 — 실패 시 null
export async function verifyApiToken(token: string): Promise<ApiTokenPayload | null> {
  try {
    const { payload } = await jwtVerify(token, secret);
    if (payload.type !== TOKEN_TYPE) return null;
    if (!payload.sub) return null;
    return { sub: payload.sub, role: String(payload.role ?? ""), type: TOKEN_TYPE };
  } catch (e) {
    logger.warn("Auth", `API 토큰 검증 실패: ${e instanceof Error ? e.message : e}`);
    return null;
  }
}

// Authorization 헤더에서 Bearer 토큰 추출
export function extractBearerToken(req: Request): string | null {
  const header = req.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return null;
  return header.slice(7).trim();
}