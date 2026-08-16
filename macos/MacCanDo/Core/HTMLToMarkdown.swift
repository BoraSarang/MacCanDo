// [FEATURE] HTML → 마크다운 변환기 (T-10)
// 기존 HTML 글을 MD 에디터로 열 때 사용. 손실 최소화 (span/font 화이트리스트는 유지)
import Foundation

enum HTMLToMarkdown {
    static func convert(_ html: String) -> String {
        var s = html

        // 1) figure(img+caption) → [img:url caption=...]
        s = replaceMatches(in: s, pattern: #"<figure[^>]*>\s*<img[^>]*src="([^"]+)"[^>]*>\s*(?:<figcaption[^>]*>(.*?)</figcaption>)?\s*</figure>"#) { _, caps in
            guard let url = caps[0] else { return "" }
            let caption = caps[1].map { escapeText($0) } ?? ""
            var out = "[img:\(url)"
            if !caption.isEmpty { out += " caption=\(caption)" }
            return out + "]"
        }

        // 2) iframe(youtube) → [youtube:ID ...]
        s = replaceMatches(in: s, pattern: #"<iframe[^>]*src="[^"]*youtube\.com/embed/([A-Za-z0-9_-]{11})[^"]*"[^>]*>"#) { _, caps in
            guard let id = caps[0] else { return "" }
            return "[youtube:\(id)]"
        }

        // 3) video → [video:url]
        s = replaceMatches(in: s, pattern: #"<video[^>]*>(?:<source[^>]*src="([^"]+)"[^>]*>)?.*?</video>"#) { _, caps in
            guard let url = caps[0] else { return "" }
            return "[video:\(url)]"
        }

        // 4) img → ![alt](url)
        s = replaceMatches(in: s, pattern: #"<img[^>]*src="([^"]+)"[^>]*alt="([^"]*)"[^>]*/?>"#) { _, caps in
            "[![\(caps[1] ?? "")](\(caps[0] ?? ""))]"
        }
        s = replaceMatches(in: s, pattern: #"<img[^>]*src="([^"]+)"[^>]*/?>"#) { _, caps in
            guard let url = caps[0] else { return "" }
            return "![](\(url))"
        }

        // 5) 링크
        s = replaceMatches(in: s, pattern: #"<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#) { _, caps in
            let url = caps[0] ?? ""
            let text = escapeText(caps[1] ?? "")
            return "[\(text)](\(url))"
        }

        // 6) 강조
        s = replaceMatches(in: s, pattern: #"<(?:strong|b)[^>]*>(.*?)</(?:strong|b)>"#) { _, caps in
            "**\(caps[0] ?? "")**"
        }
        s = replaceMatches(in: s, pattern: #"<(?:em|i)[^>]*>(.*?)</(?:em|i)>"#) { _, caps in
            "*\(caps[0] ?? "")*"
        }
        s = replaceMatches(in: s, pattern: #"<(?:del|s|strike)[^>]*>(.*?)</(?:del|s|strike)>"#) { _, caps in
            "~~\(caps[0] ?? "")~~"
        }

        // 7) 제목
        s = replaceMatches(in: s, pattern: #"<h([1-6])[^>]*>(.*?)</h\1>"#) { _, caps in
            guard let level = caps[0], let text = caps[1] else { return "" }
            return String(repeating: "#", count: Int(level) ?? 1) + " \(escapeText(text))\n\n"
        }

        // 8) 목록
        s = replaceMatches(in: s, pattern: #"<ul[^>]*>(.*?)</ul>"#) { _, caps in
            var out = ""
            for item in splitItems(caps[0] ?? "") {
                out += "- \(escapeText(item))\n"
            }
            return out + "\n"
        }
        s = replaceMatches(in: s, pattern: #"<ol[^>]*>(.*?)</ol>"#) { _, caps in
            var out = ""
            var n = 1
            for item in splitItems(caps[0] ?? "") {
                out += "\(n). \(escapeText(item))\n"
                n += 1
            }
            return out + "\n"
        }

        // 9) 인용
        s = replaceMatches(in: s, pattern: #"<blockquote[^>]*>(.*?)</blockquote>"#) { _, caps in
            let body = caps[0] ?? ""
            return body.split(separator: "\n").map { "> \($0)" }.joined(separator: "\n") + "\n\n"
        }

        // 10) 코드블록
        s = replaceMatches(in: s, pattern: #"<pre[^>]*><code[^>]*>(.*?)</code></pre>"#) { _, caps in
            "```\n\(caps[0] ?? "")\n```\n\n"
        }

        // 11) 줄바꿈/단락
        s = s.replacingOccurrences(of: "<br>", with: "\n")
        s = s.replacingOccurrences(of: "<br/>", with: "\n")
        s = s.replacingOccurrences(of: "</p>", with: "\n\n")
        s = s.replacingOccurrences(of: "</li>", with: "\n")
        s = s.replacingOccurrences(of: "</h1></h2></h3></h4></h5></h6>", with: "")

        // 12) span/font 화이트리스트는 유지, 그 외 태그 제거
        s = s.replacingOccurrences(of: #"<span\s+style="((?:color|background-color|font-size|font-family|font-weight):[^"]*)"[^>]*>[^<]*</span>"#, with: "$0", options: .regularExpression)
        s = removeTags(s, keep: ["span", "font"])

        // 정리: 중복 빈 줄
        while s.contains("\n\n\n") { s = s.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func splitItems(_ inner: String) -> [String] {
        var items: [String] = []
        var current = ""
        var depth = 0
        for ch in inner {
            if ch == "<" { depth += 1 }
            if ch == ">" { depth = max(0, depth - 1) }
            if depth == 0 && ch == "\n" {
                if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                    items.append(current)
                }
                current = ""
            } else {
                current.append(ch)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(current)
        }
        return items
    }

    private static func removeTags(_ s: String, keep: [String]) -> String {
        var out = s
        let keepSet = Set(keep)
        // <tag ...> / </tag> 제거 (keep 제외)
        out = replaceMatches(in: out, pattern: #"</?([a-zA-Z0-9]+)(?:\s[^>]*)?/?>"#) { _, caps in
            guard let tag = caps[0]?.lowercased() else { return "" }
            if keepSet.contains(tag) { return "<\(caps[0]!)>" }
            return ""
        }
        return out
    }

    private static func escapeText(_ s: String) -> String {
        s.replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

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
}