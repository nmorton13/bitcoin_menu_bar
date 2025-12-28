import SwiftUI
import Combine
import AppKit

struct BitcoinMenuView: View {
    @ObservedObject var store: BlockStore
    @ObservedObject var settings: SettingsStore
    private static let numberFormatter = makeNumberFormatter()
    private static let priceFormatter = makePriceFormatter()

    // Bitcoin orange/amber theme
    private let accentColor = Color.orange

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snapshot = store.snapshot {
                // Header Card - Block Info
                if let block = snapshot.block {
                    let date = Date(timeIntervalSince1970: block.timestamp)
                    HStack(spacing: 10) {
                        // Bitcoin icon box
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentColor.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Text("₿")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(accentColor)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Block #\(formatNumber(block.height))")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Text("\(timeAgoSimple(from: date, now: now)) ago")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(formatNumber(block.txCount))")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            Text("txns")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Price & Sats Row
                HStack(spacing: 6) {
                    if let price = snapshot.priceUSD {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Price")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let change = snapshot.priceChange24h {
                                    HStack(spacing: 2) {
                                        Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                            .font(.system(size: 8, weight: .bold))
                                        Text("\(String(format: "%.1f", abs(change)))%")
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                    }
                                    .foregroundStyle(change >= 0 ? .green : .red)
                                }
                            }
                            Text("$\(formatPrice(price))")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let sats = snapshot.satsPerDollar {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sats/$")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(formatNumber(sats))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                // Fees Row
                if let fees = snapshot.fees {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Fees")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("sat/vB")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }

                        HStack(spacing: 6) {
                            FeeBox(label: "Low", value: formatFee(fees.hourFee), color: .green)
                            FeeBox(label: "Med", value: formatFee(fees.halfHourFee), color: .yellow)
                            FeeBox(label: "High", value: formatFee(fees.fastestFee), color: .red)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Difficulty Row
                if let difficulty = snapshot.difficulty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Difficulty")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let delta = difficulty.estimatedDifficultyDelta {
                                let sign = delta >= 0 ? "+" : ""
                                Text("\(sign)\(String(format: "%.1f", delta))%")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(delta >= 0 ? .green : .red)
                            }
                        }

                        // Progress bar
                        if let progress = difficulty.progressPercent {
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.1))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(accentColor)
                                    .frame(width: max(0, 240 * progress / 100), height: 6)
                            }

                            HStack {
                                Text("\(String(format: "%.0f", progress))%")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let remaining = difficulty.remainingBlocks {
                                    let days = Double(remaining) * 10.0 / 60.0 / 24.0
                                    Text("~\(String(format: "%.1f", days)) days")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if let avg = difficulty.averageBlockTime {
                            let avgSeconds = avg / 1000.0
                            let minutes = Int(avgSeconds) / 60
                            let seconds = Int(avgSeconds) % 60
                            HStack {
                                Text("Avg block")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(minutes)m \(seconds)s")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Link to mempool.space
                Button(action: {
                    if let url = URL(string: "https://mempool.space") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 9))
                        Text("mempool.space")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)

            } else {
                HStack {
                    if store.isFetching {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text(store.errorMessage ?? "Loading...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let error = store.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            if let snapshot = store.snapshot {
                HStack {
                    Text("Updated \(timeAgoSimple(from: snapshot.fetchedAt, now: now)) ago")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let source = snapshot.priceSource {
                        Text("Price: \(source.label)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 2)
            }

            Divider()

            // Menu Actions
            VStack(spacing: 0) {
                MenuButton(
                    icon: "arrow.clockwise",
                    title: store.isFetching ? "Refreshing..." : "Refresh Now",
                    disabled: store.isFetching
                ) {
                    Task { await store.refresh() }
                }

                Menu {
                    Menu("Refresh: \(settings.refreshInterval.label)") {
                        ForEach(RefreshInterval.allCases) { option in
                            Button {
                                settings.setRefreshInterval(option)
                            } label: {
                                if settings.refreshInterval == option {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    }
                    Menu("Icon: \(settings.iconStyle.label)") {
                        ForEach(IconStyle.allCases) { option in
                            Button {
                                settings.setIconStyle(option)
                            } label: {
                                if settings.iconStyle == option {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    }
                    Toggle("Launch at login", isOn: Binding(get: {
                        settings.launchAtLogin
                    }, set: { value in
                        settings.toggleLaunchAtLogin(value)
                    }))
                    if let launchError = settings.launchError {
                        Text("Launch failed: \(launchError)")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                            .frame(width: 14)
                            .foregroundStyle(.secondary)
                        Text("Settings")
                            .font(.system(size: 12))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                MenuButton(
                    icon: "info.circle",
                    title: "About BitcoinBar"
                ) {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }

                Divider()
                    .padding(.vertical, 4)

                MenuButton(
                    icon: nil,
                    title: "Quit"
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(8)
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }

    private func formatNumber(_ number: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatPrice(_ price: Double) -> String {
        Self.priceFormatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
    }

    private func formatFee(_ fee: Double) -> String {
        let isWhole = abs(fee.rounded() - fee) < 0.0001
        if fee >= 10 {
            return String(format: isWhole ? "%.0f" : "%.1f", fee)
        } else if fee >= 1 {
            return String(format: isWhole ? "%.0f" : "%.1f", fee)
        } else {
            return String(format: "%.1f", fee)
        }
    }

    private func timeAgoSimple(from date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 5 {
            return "just now"
        }
        if seconds < 60 {
            return "\(seconds) seconds"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours) \(hours == 1 ? "hour" : "hours")"
        } else {
            let days = seconds / 86400
            return "\(days) \(days == 1 ? "day" : "days")"
        }
    }

    private static func makeNumberFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }

    private static func makePriceFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

struct MenuButton: View {
    let icon: String?
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .frame(width: 14)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(disabled ? .tertiary : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isHovered && !disabled
                    ? Color.primary.opacity(0.08)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct FeeBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
