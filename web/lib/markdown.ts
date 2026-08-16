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

export function renderMarkdown(md: string): string {
  let html = "";
  let inCodeBlock = false;
  let codeBuf: string[] = [];
  let listBuf: string[] = [];
  let listType: "ul" | "ol" = "ul";

  const flushList = () => {
    if (listBuf.length === 0) return;
    html += `<${listType}>`;
    for (const item of listBuf) html += `<li>${inline(item)}</li>`;
    html += `</${listType}>`;
    listBuf = [];
  };

  for (const rawLine of md.split("\n")) {
    const line = rawLine.trim();

    if (line.startsWith("```")) {
      if (inCodeBlock) {
        html += `<pre><code>${codeBuf.join("\n")}</code></pre>`;
        codeBuf = [];
        inCodeBlock = false;
      } else {
        flushList();
        inCodeBlock = true;
      }
      continue;
    }
    if (inCodeBlock) {
      codeBuf.push(escapeHtml(line));
      continue;
    }
    if (line === "") {
      flushList();
      continue;
    }

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
  flushList();
  if (inCodeBlock) html += `<pre><code>${codeBuf.join("\n")}</code></pre>`;
  return html;
}