// [FEATURE] 경량 마크다운 → HTML 변환기 (T-10 확장)
// 표준 MD + MacCanDo 확장 문법:
//   [youtube:ID] [youtube:ID width=800 height=450 autoplay=1 start=90]
//   [img:URL width=600 caption=캡션]  /  ![alt](url)
//   [video:URL width=640 autoplay=0]
// HTML 인라인 화이트리스트: <span style>, <font color size> (폰트/색상)
// 서버 의존 없이 로컬 렌더. macOS 미리보기와 웹 렌더러(markdown.ts) 동일 규격.
import Foundation

enum MarkdownRenderer {
    static func render(_ md: String) -> String {
        var html = ""
        var inCodeBlock = false
        var codeBuf: [String] = []
        var listBuf: [String] = []
        var listType = "ul"

        func flushList() {
            guard !listBuf.isEmpty else { return }
            html += "<\(listType)>"
            for item in listBuf { html += "<li>\(inline(item))</li>" }
            html += "</\(listType)>"
            listBuf = []
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
                    flushList()
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                codeBuf.append(escape(line))
                continue
            }

            // 빈 줄 → 리스트/단락 구분
            if line.isEmpty {
                flushList()
                continue
            }

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
        flushList()
        if inCodeBlock {
            html += "<pre><code>\(codeBuf.joined(separator: "\n"))</code></pre>"
        }
        return html
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