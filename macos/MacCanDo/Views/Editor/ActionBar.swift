// [FEATURE] T-90: 액션바 — 6단계 파이프라인 진행 표시 + 액션 (v2.15)
import SwiftUI

struct ActionBar: View {
    @Binding var currentStep: PipelineStep
    @Binding var stepStatuses: [PipelineStep: StepStatus]
    @Binding var canProceed: Bool
    
    let onStepTap: (PipelineStep) -> Void
    let onExecuteStep: (PipelineStep) -> Void
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 단계 진행 바
            HStack(spacing: 0) {
                ForEach(PipelineStep.allCases) { step in
                    StepNode(
                        step: step,
                        status: stepStatuses[step] ?? .pending,
                        isCurrent: step == currentStep,
                        onTap: { onStepTap(step) }
                    )
                    
                    if step != .publish {
                        StepConnector(status: stepStatuses[step] ?? .pending)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // 현재 단계 액션 버튼
            Divider()
            
            HStack(spacing: 12) {
                // 단계 정보
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentStep.label)
                        .font(.subheadline.bold())
                    Text(currentStep.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 액션 버튼
                HStack(spacing: 8) {
                    if currentStep != .research {
                        Button("이전 단계") {
                            if let idx = PipelineStep.allCases.firstIndex(of: currentStep),
                               idx > 0 {
                                onStepTap(PipelineStep.allCases[idx - 1])
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    let status = stepStatuses[currentStep] ?? .pending
                    if status == .completed {
                        Button("재실행") { onExecuteStep(currentStep) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("다음 단계") {
                            if let idx = PipelineStep.allCases.firstIndex(of: currentStep),
                               idx < PipelineStep.allCases.count - 1 {
                                onStepTap(PipelineStep.allCases[idx + 1])
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else if status == .inProgress {
                        Button("진행 중…") { }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(true)
                    } else {
                        Button(canProceed ? "시작" : "준비 필요") { onExecuteStep(currentStep) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(!canProceed)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.dsSurface)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Pipeline Step

enum PipelineStep: Int, CaseIterable, Identifiable {
    case research = 0      // 🔍 리서치
    case plan = 1          // 📝 기획
    case draft = 2         // ✍️ 초안
    case images = 3        // 🖼 이미지
    case prepare = 4       // ✅ 발행준비
    case publish = 5       // 🚀 발행
    
    var id: Int { rawValue }
    
    var icon: String {
        ["magnifyingglass", "list.bullet.clipboard", "pencil.and.outline", "photo.badge.sparkles", "checkmark.seal", "paperplane"][rawValue]
    }
    
    var label: String {
        ["리서치", "기획", "초안", "이미지", "발행준비", "발행"][rawValue]
    }
    
    var description: String {
        [
            "주제 입력 → 자료 수집/요약/앱 후보 자동 수집",
            "구조/섹션/이미지 프롬프트 제안 (수정 가능)",
            "본문 + 이미지 프롬프트 + 앱 카드 생성",
            "프롬프트 세트 → 복사/생성/수동 선택",
            "SEO/슬러그/카테고리/태그/썸네일 검증",
            "로컬 초안 → 서버 동기화 → 웹 반영"
        ][rawValue]
    }
}

enum StepStatus {
    case pending      // 회색
    case inProgress   // 파란색 (애니메이션)
    case completed    // 초록색
    case failed       // 빨간색
    
    var color: Color {
        switch self {
        case .pending: return Color.dsTextTertiary
        case .inProgress: return Color.dsPrimary
        case .completed: return Color.dsSuccess
        case .failed: return Color.dsDanger
        }
    }
}

// MARK: - Step Node

private struct StepNode: View {
    let step: PipelineStep
    let status: StepStatus
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(status.color.opacity(isCurrent ? 1 : 0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(isCurrent ? Color.dsPrimary : Color.clear, lineWidth: 2)
                        )
                    
                    if status == .inProgress {
                        ProgressView()
                            .controlSize(.mini)
                    } else if status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: step.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isCurrent ? .white : status.color)
                    }
                }
                
                Text(step.label)
                    .font(.caption2)
                    .foregroundStyle(isCurrent ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step Connector

private struct StepConnector: View {
    let status: StepStatus
    
    var body: some View {
        Rectangle()
            .fill(status == .completed ? Color.dsSuccess : Color.dsSurfaceHover)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
    }
}

// MARK: - Preview
#Preview {
    ActionBar(
        currentStep: .constant(.draft),
        stepStatuses: .constant([
            .research: .completed,
            .plan: .completed,
            .draft: .inProgress,
            .images: .pending,
            .prepare: .pending,
            .publish: .pending
        ]),
        canProceed: .constant(true),
        onStepTap: { _ in },
        onExecuteStep: { _ in },
        onReset: { }
    )
    .frame(width: 800)
    .padding()
}