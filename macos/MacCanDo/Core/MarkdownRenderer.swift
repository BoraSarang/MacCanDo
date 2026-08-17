// [FEATURE] 경량 마크다운 → HTML 변환기 (T-10 확장)
// 표준 MD + MacCanDo 확장 문법:
//   [youtube:ID] [youtube:ID width=800 height=450 autoplay=1 start=90]
//   [img:URL width=600 caption=캡션]  /  ![alt](url)
//   [video:URL width=640 autoplay=0]
//   [app]~[/app] 앱 카드 (T-15, render(md, apps:) 경유)
// HTML 인라인 화이트리스트: <span style>, <font color size> (폰트/색상)
// 서버 의존 없이 로컬 렌더. macOS 미리보기와 웹 렌더러(markdown.ts) 동일 규격.
import Foundation

// T-15: 앱 카드 데이터 (웹 AppCardData와 동일 규격)
struct AppStoreInfo: Codable {
    var appName: String?
    var version: String?
    var sellerName: String?
    var price: String?
    var isFree: Bool?
    var languages: [String]?
    var minimumOsVersion: String?
    var currentVersionReleaseDate: String?
    var rating: Double?
    var ratingCount: Int?
    var artworkUrl100: String?
    var fileSizeBytes: Int?
    var sellerUrl: String?
}

struct AppCardLink: Codable {
    var id: String
    var label: String
}

struct AppCardData: Codable {
    var appName: String?
    var storeInfo: AppStoreInfo?
    var homepageUrl: String?
    var appUrl: String?
    var downloadLinks: [AppCardLink]
}

enum MarkdownRenderer {
    static func render(_ md: String, apps: [AppCardData] = []) -> String {
        var html = ""
        var inCodeBlock = false
        var codeBuf: [String] = []
        var listBuf: [String] = []
        var listType = "ul"
        var tableBuf: [String] = []
        var galleryBuf: [String] = []
        var inGallery = false
        var inApp = false
        var appIndex = 0

        func flushList() {
            guard !listBuf.isEmpty else { return }
            html += "<\(listType)>"
            for item in listBuf { html += "<li>\(inline(item))</li>" }
            html += "</\(listType)>"
            listBuf = []
        }

        // GFM 테이블 — 웹 lib/markdown.ts와 동일 규격 (T-10)
        func flushTable() {
            guard !tableBuf.isEmpty else { return }
            if tableBuf.count < 2 {
                for t in tableBuf { html += "<p>\(inline(t))</p>" }
                tableBuf = []
                return
            }
            if isTableSeparator(tableBuf[1]) {
                let head = tableCells(tableBuf[0]).map { "<th>\($0)</th>" }.joined()
                var body = ""
                for row in tableBuf.dropFirst(2) where !isTableSeparator(row) {
                    body += "<tr>\(tableCells(row).map { "<td>\($0)</td>" }.joined())</tr>"
                }
                html += "<div class=\"overflow-x-auto\"><table><thead><tr>\(head)</tr></thead><tbody>\(body)</tbody></table></div>"
            } else {
                for t in tableBuf { html += "<p>\(inline(t))</p>" }
            }
            tableBuf = []
        }

        // [gallery] 블록 → 그리드 (T-13, 웹 markdown.ts와 동일 규격)
        func flushGallery() {
            guard !galleryBuf.isEmpty else { return }
            var items: [String] = []
            for l in galleryBuf {
                if let m = l.firstMatch(of: #/^!\[([^\]]*)\]\(([^)]+)\)$/#) {
                    items.append("<figure><img src=\"\(escape(String(m.2)))\" alt=\"\(escape(String(m.1)))\" loading=\"lazy\"/></figure>")
                } else if let m = l.firstMatch(of: #/^\[img:([^\s\]]+)([^\]]*)\]$/#) {
                    let params = parseParams(String(m.2))
                    let caption = params["caption"].map { "<figcaption>\(escape($0))</figcaption>" } ?? ""
                    items.append("<figure><img src=\"\(escape(String(m.1)))\" alt=\"\(escape(params["caption"] ?? ""))\" loading=\"lazy\"/>\(caption)</figure>")
                }
            }
            galleryBuf = []
            guard !items.isEmpty else { return }
            html += "<div class=\"gallery-grid\">\(items.joined())</div>"
        }

        func flushAll() {
            flushList()
            flushTable()
            flushGallery()
        }

        // [app] 블록 → 앱 카드 (T-15, 웹 markdown.ts와 동일 규격)
        func flushApp() {
            let app = appIndex < apps.count ? apps[appIndex] : nil
            appIndex += 1
            html += buildAppCardHTML(app, index: appIndex - 1)
        }

        for rawLine in md.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // 코드블록 토글
            if line.hasPrefix("```") {
                if inCodeBlock {
                    html += "<pre><code>\(codeBuf.joined(separator: "\n"))</code></pre>"
                    codeBuf = []
                    inCodeBlock = false
                } else {
                    flushAll()
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                codeBuf.append(escape(line))
                continue
            }

            // 빈 줄 → 리스트/테이블/단락 구분
            if line.isEmpty {
                flushAll()
                continue
            }

            // GFM 테이블 행 (|로 시작+끝)
            if line.hasPrefix("|") && line.hasSuffix("|") {
                flushList()
                tableBuf.append(line)
                continue
            }
            flushTable()

            // [gallery] 확장 블록 (T-13)
            if line == "[gallery]" {
                flushAll()
                inGallery = true
                galleryBuf = []
                continue
            }
            if line == "[/gallery]" {
                flushGallery()
                inGallery = false
                continue
            }
            if inGallery {
                if !line.isEmpty { galleryBuf.append(line) }
                continue
            }

            // [app] 확장 블록 (T-15)
            if line == "[app]" {
                flushAll()
                inApp = true
                continue
            }
            if line == "[/app]" {
                flushApp()
                inApp = false
                continue
            }
            if inApp { continue }

            // 목록
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if !listBuf.isEmpty && listType != "ul" { flushList() }
                listType = "ul"
                listBuf.append(String(line.dropFirst(2)))
                continue
            }
            if line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                if !listBuf.isEmpty && listType != "ol" { flushList() }
                listType = "ol"
                listBuf.append(String(line.split(separator: " ", maxSplits: 1)[1]))
                continue
            }
            flushList()

            // 확장 블록: 유튜브 / 동영상 (라인 단독)
            if let yt = youtubeBlock(line) {
                html += yt
                continue
            }
            if let v = videoBlock(line) {
                html += v
                continue
            }

            // 제목
            if let h = headingLevel(line) {
                html += "<h\(h)>\(inline(String(line.dropFirst(h + 1))))</h\(h)>"
                continue
            }
            // 인용
            if line.hasPrefix("> ") {
                html += "<blockquote>\(inline(String(line.dropFirst(2))))</blockquote>"
                continue
            }
            // 가로선
            if line == "---" || line == "***" {
                html += "<hr/>"
                continue
            }
            html += "<p>\(inline(line))</p>"
        }
        flushAll()
        if inCodeBlock {
            html += "<pre><code>\(codeBuf.joined(separator: "\n"))</code></pre>"
        }
        return html
    }

    // ---------- 앱 카드 HTML (T-15, 웹 markdown.ts와 동일 규격) ----------

    static func buildAppCardHTML(_ app: AppCardData?, index: Int) -> String {
        let info = app?.storeInfo
        let name = app?.appName ?? info?.appName ?? "앱"
        var rows: [(String, String?)] = [
            ("버전", info?.version),
            ("개발자", info?.sellerName),
            ("가격", info?.price ?? (info?.isFree == true ? "무료" : nil)),
            ("언어", info?.languages?.joined(separator: ", ")),
            ("호환", info?.minimumOsVersion.map { "macOS \($0) 이상" }),
            ("업데이트", fmtDate(info?.currentVersionReleaseDate)),
            ("크기", fmtBytes(info?.fileSizeBytes)),
        ]
        if let rating = info?.rating {
            rows.append(("평점", "★ \(String(format: "%.1f", rating)) (\((info?.ratingCount ?? 0).formatted()))"))
        }
        let specRows = rows
            .compactMap { (k, v) -> String? in
                guard let v else { return nil }
                return "<div class=\"spec-row\"><span class=\"spec-k\">\(escape(k))</span><span class=\"spec-v\">\(escape(v))</span></div>"
            }
            .joined()
        let icon: String
        if let art = info?.artworkUrl100, !art.isEmpty {
            icon = "<img src=\"\(escape(art))\" class=\"app-icon\" alt=\"\" loading=\"lazy\"/>"
        } else {
            let ch = name.first.map { String($0).uppercased() } ?? "?"
            icon = "<div class=\"app-icon-placeholder\">\(escape(ch))</div>"
        }
        let dlButtons = (app?.downloadLinks ?? []).map { dl in
            "<a class=\"app-dl\" href=\"#\" rel=\"nofollow\">\(escape(dl.label))</a>"
        }.joined()
        let home: String
        if let h = app?.homepageUrl, !h.isEmpty {
            home = "<a class=\"app-home\" href=\"\(escape(h))\" target=\"_blank\" rel=\"noopener noreferrer\">홈페이지 ↗</a>"
        } else if let s = info?.sellerUrl, !s.isEmpty {
            home = "<a class=\"app-home\" href=\"\(escape(s))\" target=\"_blank\" rel=\"noopener noreferrer\">홈페이지 ↗</a>"
        } else {
            home = ""
        }
        let store: String
        if let u = app?.appUrl, !u.isEmpty {
            store = "<a class=\"app-home\" href=\"\(escape(u))\" target=\"_blank\" rel=\"noopener noreferrer\">App Store ↗</a>"
        } else {
            store = ""
        }
        let seller = info?.sellerName.map { "<div class=\"app-seller\">\(escape($0))</div>" } ?? ""
        return "<div class=\"app-card\" data-app-index=\"\(index)\"><div class=\"app-card-top\">\(icon)<div class=\"app-card-title\"><div class=\"app-name\">\(escape(name))</div>\(seller)</div></div><div class=\"app-specs\">\(specRows)</div><div class=\"app-actions\">\(dlButtons)\(home)\(store)</div></div>"
    }

    private static func fmtDate(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime]
        guard let d = isoFmt.date(from: iso) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy. M. d."
        return f.string(from: d)
    }

    private static func fmtBytes(_ n: Int?) -> String? {
        guard let n, n > 0 else { return nil }
        return n >= 1_048_576 ? "\(n / 1_048_576) MB" : "\(n / 1024) KB"
    }

    // ---------- GFM 테이블 (웹 markdown.ts와 동일 규격) ----------

    // "| --- | :---: |" 같은 구분선인지
    static func isTableSeparator(_ line: String) -> Bool {
        line.range(of: #"^\|?[\s:|-]+\|?$"#, options: .regularExpression) != nil && line.contains("-")
    }

    // "| a | b |" → ["a", "b"] (인라인 변환 적용)
    static func tableCells(_ line: String) -> [String] {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        return s.components(separatedBy: "|").map { inline($0.trimmingCharacters(in: .whitespaces)) }
    }

    // ---------- 확장 블록 ----------

    // [youtube:VIDEO_ID] 또는 [youtube:VIDEO_ID width=800 height=450 autoplay=1 start=90]
    static func youtubeBlock(_ line: String) -> String? {
        guard line.hasPrefix("[youtube:") && line.hasSuffix("]") else { return nil }
        let inner = String(line.dropFirst(9).dropLast())
        let parts = inner.split(separator: " ", maxSplits: 1)
        guard let id = parts.first, id.count == 11 else { return nil }
        let params = parseParams(parts.count > 1 ? String(parts[1]) : "")
        let width = params["width"] ?? "560"
        let height = params["height"] ?? "315"
        var q = ""
        if params["autoplay"] == "1" { q += "&autoplay=1" }
        if let start = params["start"] { q += "&start=\(start)" }
        return "<div class=\"youtube-embed\"><iframe width=\"\(width)\" height=\"\(height)\" src=\"https://www.youtube.com/embed/\(id)?rel=0\(q)\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture\" allowfullscreen></iframe></div>"
    }

    // [video:URL width=640 autoplay=0]
    static func videoBlock(_ line: String) -> String? {
        guard line.hasPrefix("[video:") && line.hasSuffix("]") else { return nil }
        let inner = String(line.dropFirst(7).dropLast())
        let parts = inner.split(separator: " ", maxSplits: 1)
        guard let urlStr = parts.first, urlStr.hasPrefix("http") else { return nil }
        let params = parseParams(parts.count > 1 ? String(parts[1]) : "")
        let width = params["width"] ?? "640"
        let autoplay = params["autoplay"] == "1" ? " autoplay" : ""
        return "<video width=\"\(width)\" controls\(autoplay) preload=\"metadata\"><source src=\"\(escape(String(urlStr)))\" type=\"video/mp4\">이 브라우저는 동영상을 지원하지 않습니다.</video>"
    }

    // "key=value key2=value2" → [key: value]
    static func parseParams(_ s: String) -> [String: String] {
        var out: [String: String] = [:]
        for pair in s.split(separator: " ") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, kv[0].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                out[String(kv[0])] = String(kv[1])
            }
        }
        return out
    }

    private static func headingLevel(_ line: String) -> Int? {
        var n = 0
        for ch in line {
            if ch == "#" { n += 1 } else { break }
        }
        return (n >= 1 && n <= 6 && line.count > n && line[line.index(line.startIndex, offsetBy: n)] == " ") ? n : nil
    }

    // ---------- 인라인 ----------

    private static func inline(_ text: String) -> String {
        // 0) HTML 인라인 화이트리스트 (폰트/색상) — escape 전에 플레이스홀더로 보호
        var holders: [String] = []
        func protect(_ input: String, _ pattern: String, allowed: (String?) -> Bool) -> String {
            replaceMatches(in: input, pattern: pattern) { full, caps in
                guard allowed(caps.first ?? nil) else { return "" }
                let id = holders.count
                holders.append(full)
                return "\u{0}\(id)\u{0}"
            }
        }
        var s = protect(text, #"<span\s+style="([^"]*)"[^>]*>[^<]*</span>"#) { style in
            style?.range(of: #"^(color|background-color|font-size|font-family|font-weight):"#, options: .regularExpression) != nil
        }
        s = protect(s, #"<font\s+([^>]*)>[^<]*</font>"#) { attrs in
            attrs?.range(of: #"(color|size|face)="[^"]*""#, options: .regularExpression) != nil
        }
        // 1) 이스케이프
        s = escape(s)
        // 2) [img:URL width=600 caption=캡션] — 커스텀 이미지
        s = replaceMatches(in: s, pattern: #"\[img:([^\]\s]+)([^\]]*)\]"#) { _, caps in
            guard let url = caps[0] else { return "" }
            let params = parseParams(caps[1] ?? "")
            let width = params["width"].map { " width=\"\($0)\"" } ?? ""
            let caption = params["caption"].map { "<figcaption>\(escape($0))</figcaption>" } ?? ""
            return "<figure><img src=\"\(escape(url))\"\(width) loading=\"lazy\"/>\(caption)</figure>"
        }
        // 표준 이미지 ![alt](url)
        s = s.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#,
            with: "<img src=\"$2\" alt=\"$1\" loading=\"lazy\"/>",
            options: .regularExpression
        )
        // 코드
        s = s.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        // 링크 [text](url)
        s = s.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )
        // 취소선
        s = s.replacingOccurrences(of: #"~~([^~]+)~~"#, with: "<del>$1</del>", options: .regularExpression)
        // 굵게/기울임
        s = s.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "<em>$1</em>", options: .regularExpression)
        // 3) 플레이스홀더 복원
        for (i, h) in holders.enumerated() {
            s = s.replacingOccurrences(of: "\u{0}\(i)\u{0}", with: h)
        }
        return s
    }

    // 정규식 전체 매치 치환 (Foundation API 부족분 보완)
    private static func replaceMatches(
        in s: String,
        pattern: String,
        transform: (String, [String?]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return s }
        let fullRange = NSRange(s.startIndex..., in: s)
        var out = ""
        var last = s.startIndex
        for m in regex.matches(in: s, range: fullRange) {
            guard let r = Range(m.range, in: s) else { continue }
            out += s[last..<r.lowerBound]
            var caps: [String?] = []
            for i in 1..<m.numberOfRanges {
                let cr = m.range(at: i)
                caps.append(cr.location == NSNotFound ? nil : String(s[Range(cr, in: s)!]))
            }
            out += transform(String(s[r]), caps)
            last = r.upperBound
        }
        out += s[last...]
        return out
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}