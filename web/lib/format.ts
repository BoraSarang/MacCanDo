// [FEATURE] 날짜 포맷 유틸 — 상대시간 (T-18, iosgods 패턴)
// 1분 미만: 방금 전 / 60분 미만: N분 전 / 24시간 미만: N시간 전 / 7일 미만: N일 전 / 이후: 절대 날짜

export function fmtRelativeTime(d: Date | string | null): string {
  if (!d) return "";
  const date = typeof d === "string" ? new Date(d) : d;
  const diffMs = Date.now() - date.getTime();
  const min = Math.floor(diffMs / 60_000);
  if (diffMs < 60_000) return "방금 전";
  if (min < 60) return `${min}분 전`;
  const hour = Math.floor(min / 60);
  if (hour < 24) return `${hour}시간 전`;
  const day = Math.floor(hour / 24);
  if (day < 7) return `${day}일 전`;
  return new Intl.DateTimeFormat("ko-KR", { dateStyle: "medium" }).format(date);
}

// 전체 날짜 (호버/도구 설명용)
export function fmtFullDate(d: Date | string | null): string {
  if (!d) return "";
  const date = typeof d === "string" ? new Date(d) : d;
  return new Intl.DateTimeFormat("ko-KR", { dateStyle: "long" }).format(date);
}