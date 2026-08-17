// MacCanDo 확장 마크다운 렌더러 — macOS MarkdownRenderer.swift와 동일 규격 (T-10)
// 표준 MD + 확장: [youtube:ID ...] / [img:URL ...] / [video:URL ...] / HTML 인라인 화이트리스트
// XSS 방어: HTML 태그는 기본 이스케이프, span/font 화이트리스트만 통과

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function parseParams(s: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const pair of s.split(" ")) {
    const [k, ...v] = pair.split("=");
    if (k && v.length >= 1 && /^[A-Za-z0-9_]+$/.test(k)) out[k] = v.join("=");
  }
  return out;
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// 정규식 전체 매치 치환 (클로저)
function replaceAll(s: string, pattern: RegExp, transform: (full: string, caps: (string | undefined)[]) => string): string {
  const regex = new RegExp(pattern.source, "g" + (pattern.flags.includes("i") ? "i" : ""));
  let out = "";
  let last = 0;
  for (const m of s.matchAll(regex)) {
    out += s.slice(last, m.index);
    out += transform(m[0], m.slice(1));
    last = (m.index ?? 0) + m[0].length;
  }
  out += s.slice(last);
  return out;
}

// ---------- 확장 블록 ----------

function youtubeBlock(line: string): string | null {
  const m = line.match(/^\[youtube:([^\s\]]+)([^\]]*)\]$/);
  if (!m || m[1].length !== 11) return null;
  const params = parseParams(m[2]);
  const width = params.width ?? "560";
  const height = params.height ?? "315";
  let q = "";
  if (params.autoplay === "1") q += "&autoplay=1";
  if (params.start) q += `&start=${params.start}`;
  return `<div class="youtube-embed"><iframe width="${width}" height="${height}" src="https://www.youtube.com/embed/${m[1]}?rel=0${q}" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe></div>`;
}

function videoBlock(line: string): string | null {
  const m = line.match(/^\[video:([^\s\]]+)([^\]]*)\]$/);
  if (!m || !m[1].startsWith("http")) return null;
  const params = parseParams(m[2]);
  const width = params.width ?? "640";
  const autoplay = params.autoplay === "1" ? " autoplay" : "";
  return `<video width="${width}" controls${autoplay} preload="metadata"><source src="${escapeHtml(m[1])}" type="video/mp4">이 브라우저는 동영상을 지원하지 않습니다.</video>`;
}

// ---------- 인라인 ----------

function inline(text: string): string {
  // 0) HTML 인라인 화이트리스트 (폰트/색상) — escape 전에 플레이스홀더로 보호
  const holders: string[] = [];
  const protect = (input: string, pattern: RegExp, allowed: (cap?: string) => boolean): string =>
    replaceAll(input, pattern, (full, caps) => {
      if (!allowed(caps[0])) return "";
      const id = holders.length;
      holders.push(full);
      return `\u0000${id}\u0000`;
    });
  let s = protect(text, /<span\s+style="([^"]*)"[^>]*>[^<]*<\/span>/, (style) =>
    /^(color|background-color|font-size|font-family|font-weight):/.test(style ?? "")
  );
  s = protect(s, /<font\s+([^>]*)>[^<]*<\/font>/, (attrs) =>
    /(color|size|face)="[^"]*"/.test(attrs ?? "")
  );

  // 1) 이스케이프
  s = escapeHtml(s);

  // [img:URL width=600 caption=캡션]
  s = replaceAll(s, /\[img:([^\s\]]+)([^\]]*)\]/, (full, caps) => {
    const url = caps[0];
    if (!url) return "";
    const params = parseParams(caps[1] ?? "");
    const width = params.width ? ` width="${params.width}"` : "";
    const caption = params.caption ? `<figcaption>${escapeHtml(params.caption)}</figcaption>` : "";
    return `<figure><img src="${escapeHtml(url)}"${width} loading="lazy"/>${caption}</figure>`;
  });

  // 표준 이미지 ![alt](url)
  s = s.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<img src="$2" alt="$1" loading="lazy"/>');

  // 코드
  s = s.replace(/`([^`]+)`/g, "<code>$1</code>");

  // 링크
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

  // 취소선 / 굵게 / 기울임
  s = s.replace(/~~([^~]+)~~/g, "<del>$1</del>");
  s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  s = s.replace(/\*([^*]+)\*/g, "<em>$1</em>");

  // 3) 플레이스홀더 복원
  for (let i = 0; i < holders.length; i++) {
    s = s.split(`\u0000${i}\u0000`).join(holders[i]);
  }
  return s;
}

// ---------- 메인 렌더러 ----------

function parseTableRow(line: string): string {
  const cells = line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((c) => inline(c.trim()));
  return `<tr>${cells.map((c) => `<td>${c}</td>`).join("")}</tr>`;
}

function parseTableHeader(line: string): string {
  const cells = line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((c) => inline(c.trim()));
  return `<tr>${cells.map((c) => `<th>${c}</th>`).join("")}</tr>`;
}

function isTableSeparator(line: string): boolean {
  return /^\|?[\s:|-]+\|?$/.test(line) && line.includes("-");
}

export function renderMarkdown(md: string, opts: RenderOptions = {}): string {
  let html = "";
  let inCodeBlock = false;
  let codeBuf: string[] = [];
  let listBuf: string[] = [];
  let listType: "ul" | "ol" = "ul";
  let tableBuf: string[] = [];
  let tableHasHeader = false;
  let galleryBuf: string[] = [];
  let inGallery = false;
  let inApp = false;
  let appIndex = 0;

  const flushList = () => {
    if (listBuf.length === 0) return;
    html += `<${listType}>`;
    for (const item of listBuf) html += `<li>${inline(item)}</li>`;
    html += `</${listType}>`;
    listBuf = [];
  };

  const flushTable = () => {
    if (tableBuf.length === 0) return;
    if (tableBuf.length < 2) {
      for (const t of tableBuf) html += `<p>${inline(t)}</p>`;
      tableBuf = [];
      return;
    }
    if (isTableSeparator(tableBuf[1])) {
      const head = parseTableHeader(tableBuf[0]);
      const body = tableBuf
        .slice(2)
        .filter((t) => !isTableSeparator(t))
        .map(parseTableRow)
        .join("");
      html += `<div class="overflow-x-auto"><table><thead>${head}</thead><tbody>${body}</tbody></table></div>`;
      tableHasHeader = true;
    } else {
      for (const t of tableBuf) html += `<p>${inline(t)}</p>`;
    }
    tableBuf = [];
  };

  const flushAll = () => {
    flushList();
    flushTable();
    flushGallery();
  };

  // [gallery] 블록 → 그리드 (T-13, macOS 렌더러와 동일 규격)
  const flushGallery = (): string => {
    if (galleryBuf.length === 0) return "";
    const items: string[] = [];
    for (const l of galleryBuf) {
      const std = l.match(/^!\[([^\]]*)\]\(([^)]+)\)$/);
      if (std) {
        items.push(
          `<figure><img src="${escapeHtml(std[2])}" alt="${escapeHtml(std[1] ?? "")}" loading="lazy"/></figure>`
        );
        continue;
      }
      const ext = l.match(/^\[img:([^\s\]]+)([^\]]*)\]$/);
      if (ext) {
        const params = parseParams(ext[2] ?? "");
        const caption = params.caption ? `<figcaption>${escapeHtml(params.caption)}</figcaption>` : "";
        items.push(
          `<figure><img src="${escapeHtml(ext[1])}" alt="${escapeHtml(params.caption ?? "")}" loading="lazy"/>${caption}</figure>`
        );
      }
    }
    galleryBuf = [];
    if (items.length === 0) return "";
    return `<div class="gallery-grid">${items.join("")}</div>`;
  };

  // [app] 블록 → 앱 카드 (T-15, macOS 렌더러와 동일 규격)
  const flushApp = (): string => {
    const app = opts.apps?.[appIndex] ?? null;
    appIndex++;
    return buildAppCardHTML(app, appIndex - 1, opts.postSlug);
  };

  for (const rawLine of md.split("\n")) {
    const line = rawLine.trim();

    if (line.startsWith("```")) {
      if (inCodeBlock) {
        html += `<pre><code>${codeBuf.join("\n")}</code></pre>`;
        codeBuf = [];
        inCodeBlock = false;
      } else {
        flushAll();
        inCodeBlock = true;
      }
      continue;
    }
    if (inCodeBlock) {
      codeBuf.push(escapeHtml(line));
      continue;
    }
    if (line === "") {
      flushAll();
      continue;
    }

    if (line.startsWith("|") && line.endsWith("|")) {
      flushList();
      if (tableBuf.length === 1 && !tableHasHeader && isTableSeparator(line)) {
        tableBuf.push(line);
        continue;
      }
      tableBuf.push(line);
      continue;
    }
    flushTable();

    // [gallery] 확장 블록 (T-13)
    if (line === "[gallery]") {
      flushAll();
      inGallery = true;
      galleryBuf = [];
      continue;
    }
    if (line === "[/gallery]") {
      html += flushGallery();
      inGallery = false;
      continue;
    }
    if (inGallery) {
      if (line !== "") galleryBuf.push(line);
      continue;
    }

    // [app] 확장 블록 (T-15)
    if (line === "[app]") {
      flushAll();
      inApp = true;
      continue;
    }
    if (line === "[/app]") {
      html += flushApp();
      inApp = false;
      continue;
    }
    if (inApp) continue;

    if (line.startsWith("- ") || line.startsWith("* ")) {
      if (listBuf.length > 0 && listType !== "ul") flushList();
      listType = "ul";
      listBuf.push(line.slice(2));
      continue;
    }
    if (/^\d+\. /.test(line)) {
      if (listBuf.length > 0 && listType !== "ol") flushList();
      listType = "ol";
      listBuf.push(line.split(" ").slice(1).join(" "));
      continue;
    }
    flushList();

    // 확장 블록
    const yt = youtubeBlock(line);
    if (yt) { html += yt; continue; }
    const vid = videoBlock(line);
    if (vid) { html += vid; continue; }

    // 제목
    const h = line.match(/^(#{1,6}) (.+)$/);
    if (h) { html += `<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`; continue; }
    // 인용
    if (line.startsWith("> ")) { html += `<blockquote>${inline(line.slice(2))}</blockquote>`; continue; }
    // 가로선
    if (line === "---" || line === "***") { html += "<hr/>"; continue; }

    html += `<p>${inline(line)}</p>`;
  }
  flushAll();
  if (inCodeBlock) html += `<pre><code>${codeBuf.join("\n")}</code></pre>`;
  return html;
}

// ---------- 앱 카드 (T-15) ----------

export interface AppCardLink {
  id: string;
  label: string;
}

export interface AppCardData {
  appName?: string | null;
  storeInfo?: {
    appName?: string | null;
    version?: string | null;
    sellerName?: string | null;
    price?: string | null;
    isFree?: boolean | null;
    languages?: string[] | null;
    minimumOsVersion?: string | null;
    currentVersionReleaseDate?: string | null;
    rating?: number | null;
    ratingCount?: number | null;
    artworkUrl100?: string | null;
    fileSizeBytes?: number | null;
    sellerUrl?: string | null;
  } | null;
  homepageUrl?: string | null;
  appUrl?: string | null;
  downloadLinks?: AppCardLink[];
}

export interface RenderOptions {
  apps?: AppCardData[];
  postSlug?: string;
}

function fmtDate(iso?: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return `${d.getFullYear()}. ${d.getMonth() + 1}. ${d.getDate()}.`;
}

function fmtBytes(n?: number | null): string {
  if (!n) return "";
  return n >= 1048576 ? `${(n / 1048576).toFixed(0)} MB` : `${(n / 1024).toFixed(0)} KB`;
}

// [app] 블록 위치에 삽입되는 앱 카드 HTML (macOS MarkdownRenderer.swift와 동일 규격)
export function buildAppCardHTML(app: AppCardData | null, index: number, postSlug?: string): string {
  const info = app?.storeInfo ?? {};
  const name = app?.appName || info.appName || "앱";
  const rows: Array<[string, string | null | undefined]> = [
    ["버전", info.version],
    ["개발자", info.sellerName],
    ["가격", info.price ?? (info.isFree ? "무료" : null)],
    ["언어", info.languages?.join(", ")],
    ["호환", info.minimumOsVersion ? `macOS ${info.minimumOsVersion} 이상` : null],
    ["업데이트", fmtDate(info.currentVersionReleaseDate)],
    ["크기", fmtBytes(info.fileSizeBytes)],
    ["평점", typeof info.rating === "number" ? `★ ${info.rating.toFixed(1)} (${(info.ratingCount ?? 0).toLocaleString()})` : null],
  ];
  const specRows = rows
    .filter(([, v]) => v)
    .map(([k, v]) => `<div class="spec-row"><span class="spec-k">${escapeHtml(k)}</span><span class="spec-v">${escapeHtml(v!)}</span></div>`)
    .join("");
  const icon = info.artworkUrl100
    ? `<img src="${escapeHtml(info.artworkUrl100)}" class="app-icon" alt="" loading="lazy"/>`
    : `<div class="app-icon-placeholder">${escapeHtml(name.charAt(0).toUpperCase())}</div>`;
  const dlButtons = (app?.downloadLinks ?? [])
    .map((dl) => {
      const href = postSlug ? `/post/${postSlug}/download/${dl.id}` : "#";
      return `<a class="app-dl" href="${escapeHtml(href)}" rel="nofollow">${escapeHtml(dl.label)}</a>`;
    })
    .join("");
  const home =
    app?.homepageUrl || info.sellerUrl
      ? `<a class="app-home" href="${escapeHtml(app?.homepageUrl || info.sellerUrl || "#")}" target="_blank" rel="noopener noreferrer">홈페이지 ↗</a>`
      : "";
  const store = app?.appUrl
    ? `<a class="app-home" href="${escapeHtml(app.appUrl)}" target="_blank" rel="noopener noreferrer">App Store ↗</a>`
    : "";
  return `<div class="app-card" data-app-index="${index}"><div class="app-card-top">${icon}<div class="app-card-title"><div class="app-name">${escapeHtml(name)}</div>${info.sellerName ? `<div class="app-seller">${escapeHtml(info.sellerName)}</div>` : ""}</div></div><div class="app-specs">${specRows}</div><div class="app-actions">${dlButtons}${home}${store}</div></div>`;
}