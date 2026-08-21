// [FEATURE] 공통 UI 컴포넌트 (T-44) — v2.7.0 전 화면 공용
// ErrorState(아이콘+메시지+재시도) / EmptyState / StatusBar(하단 상태 바) / Badge
// 원칙: 커스텀 카드·캡슐 금지, 시스템 표면+토큰만 사용
import SwiftUI

// ---------- 에러 상태 (아이콘 + 메시지 + 재시도) ----------
struct ErrorState: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(Color.dsWarning)
            Text(message)
                .font(.dsBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            if let retry {
                Button("다시 시도", action: retry)
                    .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ---------- 빈 상태 (아이콘 + 안내) ----------
struct EmptyState: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.dsBrandGradient)
            Text(title)
                .font(.dsTitle)
            if let subtitle {
                Text(subtitle)
                    .font(.dsBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ---------- 하단 상태 바 (Finder/음악 패턴: 항목 수·선택 수) ----------
struct StatusBar: View {
    var left: String = ""
    var right: String = ""

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(left)
                .font(.dsCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(right)
                .font(.dsCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 22)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

// ---------- 상태 배지 (시스템 스타일 — SF Symbol + 토큰) ----------
// 커스텀 Capsule 배지 대체. 발행=dsPrimary, 초안=dsWarning 등 의미 체계 전 화면 동일
struct StatusBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: Capsule())
    }
}


// Notification 이름 확장 — 공통 알림 이름
