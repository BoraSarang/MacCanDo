// [FEATURE] T-85: PromptLibrary 시스템 — 템플릿 CRUD + 내장 5종 + JSON 내보내기/가져오기 (v2.15)
import Foundation
import SwiftUI

// 템플릿 카테고리
enum TemplateCategory: String, Codable, CaseIterable, Identifiable {
    case appIntro = "앱 소개형"
    case comparison = "비교 리뷰형"
    case tutorial = "튜토리얼형"
    case newsSummary = "뉴스 요약형"
    case custom = "사용자 정의"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .appIntro: return "app.badge"
        case .comparison: return "square.split.2x1"
        case .tutorial: return "list.bullet.rectangle"
        case .newsSummary: return "newspaper"
        case .custom: return "sparkles"
        }
    }
    
    var description: String {
        switch self {
        case .appIntro: return "새로운 앱/서비스를 소개하는 글 (기능/차별점/추천 대상)"
        case .comparison: return "두 개 이상의 앱/서비스를 비교 분석 (공통/차이/장단점/결론)"
        case .tutorial: return "단계별 따라하기 튜토리얼 (전제조건/절차/팁/문제해결)"
        case .newsSummary: return "최신 소식/발표를 요약하고 맥락 설명 (배경/핵심/영향/전망)"
        case .custom: return "완전 자유 구성 — 직접 섹션/프롬프트 설계"
        }
    }
}

// 이미지 위치
enum ImagePosition: String, Codable, CaseIterable, Identifiable {
    case cover
    case body1, body2, body3, body4, body5
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .cover: return "커버 이미지"
        case .body1: return "본문 1"
        case .body2: return "본문 2"
        case .body3: return "본문 3"
        case .body4: return "본문 4"
        case .body5: return "본문 5"
        }
    }
    
    var defaultAspectRatio: String {
        self == .cover ? "16:9" : "4:3"
    }
}

// 이미지 프롬프트 템플릿
struct ImagePromptTemplate: Codable, Identifiable, Hashable {
    let id: UUID
    var position: ImagePosition
    var aspectRatio: String
    var promptTemplate: String  // {appName}, {feature}, {style}, {topic} 등 변수 사용
    
    init(
        id: UUID = UUID(),
        position: ImagePosition,
        aspectRatio: String? = nil,
        promptTemplate: String
    ) {
        self.id = id
        self.position = position
        self.aspectRatio = aspectRatio ?? position.defaultAspectRatio
        self.promptTemplate = promptTemplate
    }
}

// 메인 프롬프트 템플릿
struct PromptTemplate: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: TemplateCategory
    var systemPrompt: String           // 시스템 지시문 (역할/톤/제약)
    var userPromptTemplate: String     // 사용자 프롬프트 템플릿 (변수: {topic}, {sections}, {tone}, {length}, {language})
    var imagePromptTemplates: [ImagePromptTemplate]
    var isBuiltIn: Bool
    var createdAt: Date
    var updatedAt: Date
    var version: Int                   // 템플릿 버전 (가져오기 시 충돌 방지)
    
    init(
        id: UUID = UUID(),
        name: String,
        category: TemplateCategory,
        systemPrompt: String,
        userPromptTemplate: String,
        imagePromptTemplates: [ImagePromptTemplate] = [],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.systemPrompt = systemPrompt
        self.userPromptTemplate = userPromptTemplate
        self.imagePromptTemplates = imagePromptTemplates
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.updatedAt = Date()
        self.version = 1
    }
    
    // 변수 치환 헬퍼
    func resolvedUserPrompt(
        topic: String,
        sections: [SectionPlan] = [],
        tone: String = "친근하고 전문적인",
        length: String = "충분히 상세하게 (1500~2500자)",
        language: String = "한국어"
    ) -> String {
        var prompt = userPromptTemplate
        prompt = prompt.replacingOccurrences(of: "{topic}", with: topic)
        prompt = prompt.replacingOccurrences(of: "{tone}", with: tone)
        prompt = prompt.replacingOccurrences(of: "{length}", with: length)
        prompt = prompt.replacingOccurrences(of: "{language}", with: language)
        
        if !sections.isEmpty {
            let sectionsText = sections.enumerated().map { idx, s in
                "\(idx + 1). \(s.heading): \(s.keyPoints.joined(separator: ", "))"
            }.joined(separator: "\n")
            prompt = prompt.replacingOccurrences(of: "{sections}", with: sectionsText)
        } else {
            prompt = prompt.replacingOccurrences(of: "{sections}", with: "(자동 기획됨)")
        }
        return prompt
    }
    
    func resolvedImagePrompt(
        for position: ImagePosition,
        appName: String? = nil,
        feature: String? = nil,
        style: String = "미니멀, 다크 테마, macOS 네이티브 느낌",
        topic: String? = nil
    ) -> String? {
        guard let template = imagePromptTemplates.first(where: { $0.position == position }) else { return nil }
        var prompt = template.promptTemplate
        if let appName { prompt = prompt.replacingOccurrences(of: "{appName}", with: appName) }
        if let feature { prompt = prompt.replacingOccurrences(of: "{feature}", with: feature) }
        if let topic { prompt = prompt.replacingOccurrences(of: "{topic}", with: topic) }
        prompt = prompt.replacingOccurrences(of: "{style}", with: style)
        return prompt
    }
}

// 프롬프트 라이브러리 매니저
@MainActor
final class PromptLibrary: ObservableObject {
    static let shared = PromptLibrary()
    
    @Published private(set) var templates: [PromptTemplate] = []
    @Published private(set) var lastError: String?
    
    private let userDefaultsKey = "promptTemplates"
    private let bundleResourceName = "PromptTemplates"
    
    private init() {
        load()
    }
    
    // MARK: - Public API
    
    /// 모든 템플릿 (내장 + 사용자)
    var allTemplates: [PromptTemplate] { templates }
    
    /// 내장 템플릿만
    var builtInTemplates: [PromptTemplate] { templates.filter { $0.isBuiltIn } }
    
    /// 사용자 템플릿만
    var customTemplates: [PromptTemplate] { templates.filter { !$0.isBuiltIn } }
    
    /// 카테고리별 템플릿
    func templates(for category: TemplateCategory) -> [PromptTemplate] {
        templates.filter { $0.category == category }
    }
    
    /// 템플릿 추가 (사용자 정의)
    func add(_ template: PromptTemplate) {
        var t = template
        t.updatedAt = Date()
        templates.append(t)
        save()
    }
    
    /// 템플릿 수정
    func update(_ template: PromptTemplate) {
        guard let idx = templates.firstIndex(where: { $0.id == template.id }) else { return }
        var t = template
        t.updatedAt = Date()
        t.version += 1
        templates[idx] = t
        save()
    }
    
    /// 템플릿 삭제 (내장 템플릿은 삭제 불가)
    func delete(_ template: PromptTemplate) {
        guard !template.isBuiltIn else { return }
        templates.removeAll { $0.id == template.id }
        save()
    }
    
    /// 템플릿 복제 (새 ID 생성, isBuiltIn = false)
    func duplicate(_ template: PromptTemplate) -> PromptTemplate {
        var copy = template
        copy.id = UUID()
        copy.name = "\(template.name) 복사본"
        copy.isBuiltIn = false
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.version = 1
        templates.append(copy)
        save()
        return copy
    }
    
    // MARK: - 내보내기/가져오기
    
    /// 선택한 템플릿들을 JSON Data로 내보내기
    func export(_ templates: [PromptTemplate]) -> Data? {
        let exportData = TemplateExport(
            version: 1,
            exportedAt: Date(),
            templates: templates
        )
        return try? JSONEncoder().encode(exportData)
    }
    
    /// JSON Data에서 템플릿 가져오기 (중복 처리: 동일 ID면 버전 비교, 동일 이름+카테고리면 스킵 옵션)
    func `import`(
        _ data: Data,
        skipDuplicates: Bool = true,
        overwriteBuiltIn: Bool = false
    ) -> (imported: Int, skipped: Int, errors: [String]) {
        guard let export = try? JSONDecoder().decode(TemplateExport.self, from: data) else {
            return (0, 0, ["JSON 파싱 실패: 올바른 내보내기 파일인지 확인하세요"])
        }
        
        var imported = 0
        var skipped = 0
        var errors: [String] = []
        
        for tmpl in export.templates {
            // 내장 템플릿 덮어쓰기 방지
            if tmpl.isBuiltIn && !overwriteBuiltIn {
                skipped += 1
                continue
            }
            
            // 중복 체크
            if let existing = templates.first(where: { $0.id == tmpl.id }) {
                if skipDuplicates {
                    if existing.version >= tmpl.version {
                        skipped += 1
                        continue
                    }
                    // 버전이 더 높으면 덮어쓰기
                } else if templates.contains(where: { $0.name == tmpl.name && $0.category == tmpl.category }) {
                    skipped += 1
                    continue
                }
            }
            
            var toAdd = tmpl
            toAdd.isBuiltIn = false  // 가져온 건 항상 사용자 정의
            toAdd.createdAt = Date()
            toAdd.updatedAt = Date()
            templates.append(toAdd)
            imported += 1
        }
        
        if imported > 0 { save() }
        return (imported, skipped, errors)
    }
    
    /// 내장 템플릿을 파일로 내보내기 (백업용)
    func exportBuiltInToFile() -> Data? {
        export(builtInTemplates)
    }
    
    // MARK: - 내장 템플릿 초기화
    
    private func load() {
        // 1. UserDefaults에서 사용자 템플릿 로드
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([PromptTemplate].self, from: data) {
            templates = decoded
        } else {
            templates = []
        }
        
        // 2. 번들 리소스에서 내장 템플릿 로드 (없으면 기본 내장 생성)
        if let bundleURL = Bundle.main.url(forResource: bundleResourceName, withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let builtIn = try? JSONDecoder().decode([PromptTemplate].self, from: data) {
            // 내장 템플릿은 ID 기준으로 병합 (이미 있으면 버전 체크 후 업데이트)
            for bt in builtIn {
                if let idx = templates.firstIndex(where: { $0.id == bt.id }) {
                    if templates[idx].version < bt.version {
                        templates[idx] = bt
                    }
                } else {
                    templates.append(bt)
                }
            }
        } else {
            // 번들 리소스 없으면 기본 내장 템플릿 생성
            seedBuiltInTemplates()
        }
        
        save()
    }
    
    private func save() {
        // 사용자 템플릿만 저장 (내장 템플릿은 번들 리소스에서 로드)
        let userTemplates = templates.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(userTemplates) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func seedBuiltInTemplates() {
        templates = Self.defaultBuiltInTemplates()
        // 내장 템플릿 표시
        templates = templates.map { var t = $0; t.isBuiltIn = true; return t }
    }
    
    // 기본 내장 템플릿 5종
    static func defaultBuiltInTemplates() -> [PromptTemplate] {
        [
            // 1. 앱 소개형
            PromptTemplate(
                name: "앱 소개형 (기본)",
                category: .appIntro,
                systemPrompt: """
                당신은 Mac 사용자를 위한 기술 블로그 작가입니다.
                새로운 Mac 앱/도구를 소개하는 글을 작성합니다.
                독자는 Mac을 잘 쓰는 파워 유저부터 초보자까지 다양합니다.
                """,
                userPromptTemplate: """
                주제: {topic}
                
                다음 섹션 구조로 글을 작성해 주세요 ({language}로, {tone} 톤으로, {length}):
                
                {sections}
                
                각 섹션은 구체적인 예시, 스크린샷 설명(이미지 마커 포함), 실사용 팁을 포함하세요.
                """,
                imagePromptTemplates: [
                    ImagePromptTemplate(position: .cover, promptTemplate: "{appName} macOS 앱 메인 화면, {style}, 16:9 와이드"),
                    ImagePromptTemplate(position: .body1, promptTemplate: "{appName}의 {feature} 기능 실행 화면, {style}, 4:3"),
                    ImagePromptTemplate(position: .body2, promptTemplate: "{appName} 설정/옵션 화면, {style}, 4:3"),
                ],
                isBuiltIn: true
            ),
            
            // 2. 비교 리뷰형
            PromptTemplate(
                name: "비교 리뷰형 (기본)",
                category: .comparison,
                systemPrompt: """
                당신은 객관적인 기술 리뷰어입니다.
                여러 앱/서비스를 공정하게 비교 분석하는 글을 작성합니다.
                장단점을 명확히 하고, 독자의 선택을 돕는 결론을 내립니다.
                """,
                userPromptTemplate: """
                비교 주제: {topic}
                
                다음 구조로 비교 글을 작성하세요 ({language}, {tone}, {length}):
                
                {sections}
                
                각 항목별로 표/리스트로 비교하고, 마지막에 '이런 분께 추천' 결론을 넣으세요.
                """,
                imagePromptTemplates: [
                    ImagePromptTemplate(position: .cover, promptTemplate: "{appName} vs {appName2} 비교 인포그래픽 스타일, {style}, 16:9"),
                    ImagePromptTemplate(position: .body1, promptTemplate: "{appName}와 {appName2} 기능 비교표 시각화, {style}, 4:3"),
                    ImagePromptTemplate(position: .body2, promptTemplate: "{appName} 장점 화면 예시, {style}, 4:3"),
                    ImagePromptTemplate(position: .body3, promptTemplate: "{appName2} 장점 화면 예시, {style}, 4:3"),
                ],
                isBuiltIn: true
            ),
            
            // 3. 튜토리얼형
            PromptTemplate(
                name: "튜토리얼형 (기본)",
                category: .tutorial,
                systemPrompt: """
                당신은 친절한 기술 튜토리얼 작가입니다.
                단계별로 따라하기 쉬운 가이드를 작성합니다.
                초보자도 막힘없이 완료할 수 있도록 세세하게 설명합니다.
                """,
                userPromptTemplate: """
                튜토리얼 주제: {topic}
                
                다음 구조로 단계별 가이드를 작성하세요 ({language}, {tone}, {length}):
                
                {sections}
                
                각 단계는 스크린샷 포인트(이미지 마커)와 예상 결과, 문제 발생 시 해결책을 포함하세요.
                """,
                imagePromptTemplates: [
                    ImagePromptTemplate(position: .cover, promptTemplate: "{topic} 튜토리얼 커버 - 완성 화면 미리보기, {style}, 16:9"),
                    ImagePromptTemplate(position: .body1, promptTemplate: "1단계: {feature} 설정 화면, {style}, 4:3"),
                    ImagePromptTemplate(position: .body2, promptTemplate: "2단계: {feature} 실행 중간 화면, {style}, 4:3"),
                    ImagePromptTemplate(position: .body3, promptTemplate: "3단계: 완료된 결과 화면, {style}, 4:3"),
                ],
                isBuiltIn: true
            ),
            
            // 4. 뉴스 요약형
            PromptTemplate(
                name: "뉴스 요약형 (기본)",
                category: .newsSummary,
                systemPrompt: """
                당신은 기술 뉴스 큐레이터입니다.
                최신 발표/소식을 맥락과 함께 요약해 독자가 바로 이해할 수 있게 씁니다.
                사실과 추측을 구분하고, 출처를 명시합니다.
                """,
                userPromptTemplate: """
                뉴스 주제: {topic}
                
                다음 구조로 요약 글을 작성하세요 ({language}, {tone}, {length}):
                
                {sections}
                
                사실(공식 발표)과 분석(해석/전망)을 명확히 구분하세요. 출처 링크는 본문 하단에 모아두세요.
                """,
                imagePromptTemplates: [
                    ImagePromptTemplate(position: .cover, promptTemplate: "{topic} 뉴스 커버 - 핵심 키워드 시각화, {style}, 16:9"),
                    ImagePromptTemplate(position: .body1, promptTemplate: "{topic} 관련 발표/로고/화면 캡처, {style}, 4:3"),
                ],
                isBuiltIn: true
            ),
            
            // 5. 사용자 정의 (빈 템플릿)
            PromptTemplate(
                name: "빈 템플릿 (직접 작성)",
                category: .custom,
                systemPrompt: "자유롭게 프롬프트를 작성하세요.",
                userPromptTemplate: "{topic}\n\n{sections}",
                imagePromptTemplates: [
                    ImagePromptTemplate(position: .cover, promptTemplate: "{topic} 커버 이미지, {style}, 16:9"),
                    ImagePromptTemplate(position: .body1, promptTemplate: "{topic} 본문 이미지 1, {style}, 4:3"),
                ],
                isBuiltIn: true
            )
        ]
    }
}

// 내보내기용 래퍼
struct TemplateExport: Codable {
    let version: Int
    let exportedAt: Date
    let templates: [PromptTemplate]
}

// 사용 예시 (Preview/테스트용)
#if DEBUG
extension PromptLibrary {
    static var preview: PromptLibrary {
        let lib = PromptLibrary.shared
        // 미리보기용 더미 데이터 주입 가능
        return lib
    }
}
#endif