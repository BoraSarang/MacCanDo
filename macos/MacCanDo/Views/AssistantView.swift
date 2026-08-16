// [FEATURE] AI 도우미 — 글쓰기 참고용 제품 소개 생성 (사용자 요청)
// 프로그램 이름 또는 웹사이트 URL 입력 → Gemini가 소개/비교/장점/특이사항/추천 MD 생성
// 참고용 데이터 — 복사해서 에디터에서 수정해 사용
import SwiftUI
import AppKit
import WebKit

struct AssistantView: View {
    @State private var query = ""
    @State private var compareWith = ""
    @State private var result = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cacheHit = false
    @State private var viewMode = "원문"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI 도우미", systemImage: "wand.and.stars")
                    .font(.title3.bold())
                Spacer()
                Text("참고용 자료 — 복사해서 글에 활용하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                TextField("프로그램 이름 또는 웹사이트 URL", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await search() } }
                Button("조회") { Task { await search() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack(spacing: 8) {
                TextField("비교 대상 (선택 — 비우면 AI가 유사 프로그램 선정)", text: $compareWith)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
                if cacheHit {
                    Label("캐시 표시됨", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.dsSuccess)
                    Button("재조회") { Task { await search(forceRefresh: true) } }
                        .controlSize(.small)
                }
            }
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("정보 조회 및 생성 중…").font(.dsBody).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button("다시 시도") { Task { await search() } }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if !result.isEmpty {
                HStack {
                    Picker("", selection: $viewMode) {
                        Text("원문 (MD)").tag("원문")
                        Text("미리보기").tag("미리보기")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    Spacer()
                    Button("복사") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                        DebugLogger.info("Assistant", "도우미 결과 복사됨")
                    }
                    .keyboardShortcut("c", modifiers: .command)
                }
                Group {
                    if viewMode == "원문" {
                        ScrollView {
                            Text(result)
                                .font(.dsMono)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                    } else {
                        AssistantPreview(html: assistantHTML(result))
                    }
                }
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color(nsColor: .textBackgroundColor)))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("프로그램 이름이나 웹사이트 주소를 입력하면\n소개·비교·장점·특이사항·추천 이유를 생성합니다.")
                        .font(.dsBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 520)
        .onAppear { DebugLogger.info("Feature", "AI 도우미 창 표시됨") }
    }

    private func assistantHTML(_ md: String) -> String {
        "<html><head><meta charset=\"utf-8\"><style>body{font-family:-apple-system,sans-serif;padding:16px;line-height:1.7;color:#222}img{max-width:100%}pre{background:#f4f4f4;padding:8px;border-radius:6px}blockquote{border-left:3px solid #ccc;margin:0;padding-left:12px;color:#555}</style></head><body>\(MarkdownRenderer.render(md))</body></html>"
    }

    private func search(forceRefresh: Bool = false) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        cacheHit = false
        do {
            // URL이면 페이지 fetch (실패 시 이름 기반 폴백)
            var urlContent: String?
            if q.lowercased().hasPrefix("http") {
                do {
                    urlContent = try await GeminiService.fetchURLText(q)
                    DebugLogger.info("Assistant", "URL fetch 성공 (\(String(q.prefix(40)))) — \(urlContent?.count ?? 0)자")
                } catch {
                    DebugLogger.warn("Assistant", "URL fetch 실패 → 이름 기반 폴백: \(error.localizedDescription)")
                }
            }
            let compare = compareWith.trimmingCharacters(in: .whitespacesAndNewlines)
            let (text, hit) = try await GeminiService.generateProductGuide(
                query: q,
                compareWith: compare.isEmpty ? nil : compare,
                urlContent: urlContent,
                forceRefresh: forceRefresh
            )
            result = text
            cacheHit = hit
            DebugLogger.info("Assistant", "도우미 생성 완료 (캐시: \(hit ? "hit" : "miss"))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? error.localizedDescription
            DebugLogger.error("Assistant", "도우미 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }
}

// 미리보기용 WKWebView (MarkdownRenderer 결과 표시)
struct AssistantPreview: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isInspectable = true
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
}