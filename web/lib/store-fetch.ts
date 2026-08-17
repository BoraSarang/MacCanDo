// [FEATURE] App Store lookup — T-15 (앱 카드 자동 추출)
// Apple lookup API: https://itunes.apple.com/lookup?id={appId}
// 추출 가능한 것만: 버전/개발자/가격/언어/호환 macOS/업데이트일/별점/아이콘/크기/판매자 사이트
import { logger } from "./logger";

export interface StoreAppMeta {
  appId: string;
  appName: string;
  version: string;
  sellerName: string;
  price: string; // formattedPrice (예: "₩12,000" / "무료")
  isFree: boolean;
  languages: string[]; // 한국어명
  minimumOsVersion: string | null;
  currentVersionReleaseDate: string | null;
  rating: number | null;
  ratingCount: number | null;
  artworkUrl100: string | null;
  fileSizeBytes: number | null;
  sellerUrl: string | null;
}

// ISO 639-1 (대문자) → 한국어명
const LANG_KO: Record<string, string> = {
  EN: "영어",
  KO: "한국어",
  JA: "일본어",
  "ZH-HANS": "중국어(간체)",
  "ZH-HANT": "중국어(번체)",
  ZH: "중국어",
  DE: "독일어",
  FR: "프랑스어",
  ES: "스페인어",
  IT: "이탈리아어",
  PT: "포르투갈어",
  RU: "러시아어",
  NL: "네덜란드어",
  SV: "스웨덴어",
  PL: "폴란드어",
  TR: "터키어",
  VI: "베트남어",
  ID: "인도네시아어",
  AR: "아랍어",
  TH: "태국어",
  CS: "체코어",
  UK: "우크라이나어",
  DA: "덴마크어",
  FI: "핀란드어",
  NO: "노르웨이어",
  HE: "히브리어",
  HU: "헝가리어",
  RO: "루마니아어",
  EL: "그리스어",
  HI: "힌디어",
  MS: "말레이어",
};

export function langToKo(code: string): string {
  const k = code.toUpperCase();
  return LANG_KO[k] ?? code;
}

function parseAppId(url: string): string | null {
  const trimmed = url.trim();
  const idMatch = trimmed.match(/\/id(\d{6,12})\b/i);
  if (idMatch) return idMatch[1];
  if (/^\d{6,12}$/.test(trimmed)) return trimmed;
  return null;
}

export async function lookupAppStore(url: string): Promise<StoreAppMeta | null> {
  const appId = parseAppId(url);
  if (!appId) return null;
  try {
    const res = await fetch(`https://itunes.apple.com/lookup?id=${appId}`, {
      headers: { Accept: "application/json" },
      cache: "no-store",
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    const json = (await res.json()) as {
      resultCount: number;
      results?: Array<Record<string, unknown>>;
    };
    const r = json.results?.[0];
    // mac-software = 순수 macOS, software = macOS/iOS 겸용(Catalyst) — 둘 다 허용 (T-15)
    if (json.resultCount === 0 || !r || (r.kind !== "mac-software" && r.kind !== "software")) {
      logger.info("StoreFetch", `App Store 조회 실패 (kind=${String(r?.kind ?? "?")}, id=${appId})`);
      return null;
    }
    const languages = Array.isArray(r.languages) ? (r.languages as string[]) : [];
    logger.info("StoreFetch", `App Store 조회 성공: ${String(r.trackName ?? "")} (id=${appId})`);
    return {
      appId,
      appName: String(r.trackName ?? ""),
      version: String(r.version ?? ""),
      sellerName: String(r.sellerName ?? ""),
      price: String(r.formattedPrice ?? (r.price === 0 ? "무료" : "")),
      isFree: Number(r.price ?? 1) === 0,
      languages: languages.map(langToKo),
      minimumOsVersion: r.minimumOsVersion ? String(r.minimumOsVersion) : null,
      currentVersionReleaseDate: r.currentVersionReleaseDate
        ? String(r.currentVersionReleaseDate)
        : null,
      rating: typeof r.averageUserRating === "number" ? Number(r.averageUserRating) : null,
      ratingCount:
        typeof r.userRatingCount === "number" ? Number(r.userRatingCount) : null,
      artworkUrl100: r.artworkUrl100 ? String(r.artworkUrl100) : null,
      fileSizeBytes:
        r.fileSizeBytes !== undefined && r.fileSizeBytes !== null
          ? Number(r.fileSizeBytes) || null
          : null,
      sellerUrl: r.sellerUrl ? String(r.sellerUrl) : null,
    };
  } catch (err) {
    logger.error("StoreFetch", `App Store 조회 실패: ${err instanceof Error ? err.message : err}`);
    return null;
  }
}

// App Store URL에서 ID 추출 (저장용)
export function extractAppId(url: string): string | null {
  return parseAppId(url);
}