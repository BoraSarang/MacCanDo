// [FEATURE] T-89: 리서치 패널 — 수집 결과/키워드/앱 후보 표시 (v2.15)
import SwiftUI

struct ResearchPanel: View {
    @ObservedObject var pipeline = WritingPipeline.shared
    @Binding var researchBundle: ResearchBundle?
    @Binding var selectedItems: Set<UUID>
    
    let onItemSelected: (CollectedItem) -> Void
    let onAppSelected: (AppCandidate) -> Void
    let onAddToPlan: (CollectedItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Label("리서치", systemImage: "magnifyingglass")
                    .font(.headline)
                Spacer()
                if let bundle = researchBundle {
                    Text("\(bundle.sources.count)개 소스 · \(bundle.keywords.count)개 키워드")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let bundle = researchBundle {
                // 탭: 소스 / 키워드 / 앱
                TabView {
                    // 소스 탭
                    sourcesView(bundle)
                        .tabItem { Label("소스", systemImage: "doc.text") }
                    
                    // 키워드 탭
                    keywordsView(bundle)
                        .tabItem { Label("키워드", systemImage: "tag") }
                    
                    // 앱 후보 탭
                    appsView(bundle)
                        .tabItem { Label("앱", systemImage: "app.badge") }
                }
                .frame(maxHeight: .infinity)
            } else {
                EmptyState(
                    icon: "magnifyingglass",
                    title: "수집된 자료 없음",
                    subtitle: "액션바의 [리서치]를 눌러 주제별 자료를 수집하세요"
                )
            }
        }
        .padding(12)
    }
    
    // MARK: - Subviews
    
    private func sourcesView(_ bundle: ResearchBundle) -> some View {
        List(bundle.sources, selection: $selectedItems) { item in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.sourceName)
                        .font(.caption.bold())
                        .foregroundStyle(Color.dsPrimary)
                    Spacer()
                    Text(item.publishedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                HStack {
                    Text(item.evaluation)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Spacer()
                    if !item.keywords.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(item.keywords.prefix(3), id: \.self) { kw in
                                    Text(kw)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.dsSurfaceHover)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { onItemSelected(item) }
        }
        .listStyle(.inset)
        .overlay {
            if bundle.sources.isEmpty {
                EmptyState(icon: "doc.text", title: "소스 없음", subtitle: "수집된 기사가 없습니다")
            }
        }
    }
    
    private func keywordsView(_ bundle: ResearchBundle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("핵심 키워드 (빈도순)").font(.subheadline.bold())
            
            FlowLayout(spacing: 8) {
                ForEach(bundle.keywords, id: \.self) { kw in
                    Text(kw)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.dsPrimary.opacity(0.1))
                        .foregroundStyle(Color.dsPrimary)
                        .clipShape(Capsule())
                }
            }
            
            Divider()
            
            Text("소스별 키워드 분포").font(.subheadline.bold())
            
            ForEach(bundle.sources.prefix(5)) { item in
                if !item.keywords.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.sourceName).font(.caption.bold()).foregroundStyle(Color.dsPrimary)
                        FlowLayout(spacing: 4) {
                            ForEach(item.keywords, id: \.self) { kw in
                                Text(kw)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.dsSurfaceHover)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
    }
    
    private func appsView(_ bundle: ResearchBundle) -> some View {
        List(bundle.relatedApps) { app in
            HStack(spacing: 10) {
                if let iconURL = app.iconURL {
                    AsyncImage(url: URL(string: iconURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                        case .failure:
                            Image(systemName: "app")
                                .foregroundStyle(.secondary)
                        default:
                            ProgressView()
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "app")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.subheadline.weight(.medium))
                    Text(app.category).font(.caption).foregroundStyle(.secondary)
                    Text(app.price).font(.caption.bold()).foregroundStyle(Color.dsPrimary)
                    Text(app.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { onAppSelected(app) }
        }
        .listStyle(.inset)
        .overlay {
            if bundle.relatedApps.isEmpty {
                EmptyState(icon: "app.badge", title: "관련 앱 없음", subtitle: "수집된 자료에서 앱 후보를 찾지 못했습니다")
            }
        }
    }
}

// MARK: - FlowLayout (태그 칩 배치용)

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) { self.spacing = spacing }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + spacing > width {
                height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}