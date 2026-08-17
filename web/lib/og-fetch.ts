// [FEATURE] 웹사이트 og 메타 스크래핑 — T-31
// [app:URL]이 App Store가 아닌 일반 웹사이트일 때, 저장 시점에 og:title/og:image/og:description/og:site_name을 수집해
// 앱 카드를 채운다. 렌더링 시점에는 외부 요청이 없다 (저장 시점 1회).
// og가 없는 사이트는 <title> / apple-touch-icon / favicon.ico / meta[name=description]로 폴백.
import { logger } from "./logger";

export interface OgMetadata {
  title: string;
  image: string | null;
  description: string | null;
  siteName: string | null;
  url: string; // redirect 이후 최종 URL (상대경로 이미지 절대화 기준)
}

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36 MacCanDoBot/1.0";

// HTML 엔티티 디코딩 (og:title 등에 &amp; 같은 것이 포함된 경우)
function decodeEntities(s: string): string {
  return s
    .replace(/&#x27;/gi, "'")
    .replace(/&#0?39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&apos;/g, "'");
}

function stripHtml(s: string): string {
  return s.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
}

function attr(tag: string, key: string): string | undefined {
  const m = tag.match(new RegExp(`${key}\\s*=\\s*["']([^"']*)["']`, "i"));
  return m ? m[1] : undefined;
}

// 상대 경로(/og-image.png) → 절대 URL (redirect 후 최종 URL 기준)
function absoluteUrl(rel: string, base: string): string | null {
  try {
    return new URL(rel, base).toString();
  } catch {
    return null;
  }
}

export async function fetchOgMetadata(url: string): Promise<OgMetadata | null> {
  let res: Response;
  try {
    res = await fetch(url, {
      headers: { "user-agent": UA },
      redirect: "follow",
      signal: AbortSignal.timeout(6000),
      cache: "no-store",
    });
  } catch (e) {
    logger.warn("OgFetch", `요청 실패 (${url}): ${(e as Error).message}`);
    return null;
  }
  if (!res.ok) {
    logger.warn("OgFetch", `HTTP ${res.status} (${url})`);
    return null;
  }
  let html: string;
  try {
    html = await res.text();
  } catch {
    return null;
  }
  if (html.length === 0) return null;

  const meta: Record<string, string> = {};
  for (const m of html.matchAll(/<meta\b[^>]*>/gi)) {
    const tag = m[0];
    const key = (attr(tag, "property") ?? attr(tag, "name") ?? "").toLowerCase();
    const content = attr(tag, "content");
    if (key && content !== undefined && !meta[key]) meta[key] = content;
  }

  const finalUrl = res.url || url;
  const titleRaw = meta["og:title"] ?? meta["title"] ?? html.match(/<title\b[^>]*>([^<]*)<\/title>/i)?.[1] ?? "";
  const title = stripHtml(decodeEntities(titleRaw));
  if (!title) return null; // 이름이 될 제목이 없으면 실패 처리

  const imageRaw = meta["og:image"];
  let image: string | null = imageRaw ? absoluteUrl(decodeEntities(imageRaw), finalUrl) : null;
  if (!image) {
    // apple-touch-icon → icon 순으로 폴백 (고해상도 우선)
    for (const m of html.matchAll(/<link\b[^>]*>/gi)) {
      const tag = m[0];
      const rel = (attr(tag, "rel") ?? "").toLowerCase();
      const href = attr(tag, "href");
      if (href && (rel.includes("apple-touch-icon") || rel.includes("icon"))) {
        const abs = absoluteUrl(href, finalUrl);
        if (abs) {
          image = abs;
          break;
        }
      }
    }
  }

  const descriptionRaw = meta["og:description"] ?? meta["description"];
  const description = descriptionRaw ? stripHtml(decodeEntities(descriptionRaw)) : null;
  const siteName = meta["og:site_name"] ? decodeEntities(meta["og:site_name"]).trim() : null;

  return { title, image, description, siteName, url: finalUrl };
}