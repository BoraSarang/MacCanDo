// MacCanDo 공통 로거 (19.1장 DebugLogger 규격)
// 포맷: [HH:mm:ss.SSS] [LEVEL] [FEATURE] 메시지
// 레벨: INFO / WARN / ERROR / PERF / CACHE
// API 호출: API→ {METHOD} {path} / API← {status} {ms}

type LogLevel = "INFO" | "WARN" | "ERROR" | "PERF" | "CACHE";

// 디버그 패널용 메모리 링버퍼 (최대 1000개 — /api/debug/logs에서 조회)
export interface LogEntry {
  time: string;
  level: string;
  platform: string;
  category: string;
  message: string;
  meta?: string;
  text: string;
}

const MAX_BUFFER = 1000;
const logBuffer: LogEntry[] = [];

const LEVEL_ORDER: Record<LogLevel, number> = {
  INFO: 0,
  WARN: 1,
  ERROR: 2,
  PERF: 3,
  CACHE: 4,
};

const MIN_LEVEL: LogLevel = (process.env.LOG_LEVEL as LogLevel) ?? "INFO";

function ts(): string {
  const d = new Date();
  return (
    [d.getHours(), d.getMinutes(), d.getSeconds()]
      .map((n) => String(n).padStart(2, "0"))
      .join(":") + `.${String(d.getMilliseconds()).padStart(3, "0")}`
  );
}

export function log(level: LogLevel, feature: string, message: string, meta?: unknown) {
  if (LEVEL_ORDER[level] < LEVEL_ORDER[MIN_LEVEL]) return;
  const time = ts();
  const metaStr = meta === undefined ? "" : ` ${JSON.stringify(meta)}`;
  const entry: LogEntry = {
    time,
    level,
    platform: "web",
    category: feature,
    message,
    meta: meta === undefined ? undefined : JSON.stringify(meta),
    text: `[${time}] [${level}] [${feature}] ${message}${metaStr}`,
  };
  logBuffer.push(entry);
  if (logBuffer.length > MAX_BUFFER) logBuffer.splice(0, logBuffer.length - MAX_BUFFER);
  if (level === "ERROR") console.error(entry.text);
  else console.log(entry.text);
}

// 디버그 패널용: 최근 로그 조회 (필터: level/category 정확 일치)
export function getRecentLogs(limit = 200, level = "", category = "") {
  let entries = logBuffer;
  if (level) entries = entries.filter((e) => e.level === level);
  if (category) entries = entries.filter((e) => e.category === category);
  const logs = entries.slice(-Math.min(limit, entries.length));
  return { total: entries.length, logs };
}

export const logger = {
  info: (feature: string, message: string, meta?: unknown) => log("INFO", feature, message, meta),
  warn: (feature: string, message: string, meta?: unknown) => log("WARN", feature, message, meta),
  error: (feature: string, message: string, meta?: unknown) => log("ERROR", feature, message, meta),
  perf: (feature: string, message: string, meta?: unknown) => log("PERF", feature, message, meta),
  cache: (feature: string, message: string, meta?: unknown) => log("CACHE", feature, message, meta),
  // API 호출 로깅 (8.6장 GBridge 규격): API→ GET /api/posts
  apiRequest: (method: string, path: string, meta?: unknown) =>
    log("INFO", "API", `API→ ${method} ${path}`, meta),
  // API← 200 42ms
  apiResponse: (method: string, path: string, status: number, ms: number) =>
    log("INFO", "API", `API← ${status} ${ms}ms (${method} ${path})`),
};