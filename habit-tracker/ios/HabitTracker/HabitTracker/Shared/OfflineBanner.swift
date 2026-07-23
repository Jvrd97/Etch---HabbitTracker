// [review:need-review] PHASE-01/11-ios-read-cache
// summary: honest "offline, showing cached data from <time>" banner shown on Today/Table when a load fell back to the read cache
import SwiftUI

/// Slim banner surfaced above a screen's content when its data came from the read
/// cache instead of the network. Shows the timestamp of the cached snapshot so the
/// user knows exactly how stale what they see is.
struct OfflineBanner: View {
    let updatedAt: Date

    /// "Offline · showing data from Jul 23, 14:05" — absolute so it stays honest
    /// even if the screen sits open for hours.
    static func caption(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Offline · showing data from \(formatter.string(from: date))"
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "wifi.slash")
            Text(OfflineBanner.caption(for: updatedAt))
                .font(DS.Typography.caption)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(DS.Palette.textSecondary)
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.card)
    }
}
