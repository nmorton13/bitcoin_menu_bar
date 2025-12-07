import SwiftUI
import AppKit

struct BitcoinMenuView: View {
    @ObservedObject var store: BlockStore
    @ObservedObject var settings: SettingsStore

    private let crtBlue = Color(red: 0.278, green: 0.439, blue: 0.647)
    private let crtBrightText = Color(red: 0.9, green: 0.95, blue: 1.0)
    private let crtBorder = Color(red: 0.5, green: 0.65, blue: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let snapshot = store.snapshot {
                VStack(alignment: .leading, spacing: 3) {
                    if let block = snapshot.block {
                        Text("Bitcoin Block #\(formatNumber(block.height))")
                            .font(.system(size: 13, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(crtBrightText)

                        let date = Date(timeIntervalSince1970: block.timestamp)
                        Text("Mined: \(date.formatted(date: .abbreviated, time: .standard))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(crtBrightText)

                        Text("Time ago: \(timeAgoSimple(from: date))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(crtBrightText)

                        Text("Transactions: \(formatNumber(block.txCount))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(crtBrightText)
                    }

                    if let price = snapshot.priceUSD {
                        Text("Price: \(formatPrice(price))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(crtBrightText)
                    }

                    if let sats = snapshot.satsPerDollar {
                        Text("Sats per $: \(formatNumber(sats))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(crtBrightText)
                    }

                    if let fees = snapshot.fees {
                        Text("Fees (sat/vB): \(fees.fastestFee) / \(fees.halfHourFee) / \(fees.hourFee)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(crtBrightText)
                    }

                    if let difficulty = snapshot.difficulty {
                        if let avg = difficulty.averageBlockTime {
                            let avgSeconds = avg / 1000.0  // Convert milliseconds to seconds
                            let minutes = Int(avgSeconds) / 60
                            let seconds = Int(avgSeconds) % 60
                            Text("Avg block time: \(minutes)m \(seconds)s")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(crtBrightText)
                        }

                        if let delta = difficulty.estimatedDifficultyDelta {
                            let sign = delta >= 0 ? "+" : ""
                            Text("Difficulty adj: \(sign)\(String(format: "%.2f", delta))%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(crtBrightText)
                        }

                        if let remaining = difficulty.remainingBlocks {
                            let days = Double(remaining) * 10.0 / 60.0 / 24.0
                            Text("Next adj: \(String(format: "%.1f", days)) days")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(crtBrightText)
                        }
                    }

                    Spacer()
                        .frame(height: 8)

                    Button(action: {
                        if let url = URL(string: "https://mempool.space") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("Click to view on mempool.space")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(crtBrightText)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(crtBlue)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(crtBorder, lineWidth: 2)
                )
                .padding(.horizontal, 8)
                .padding(.top, 8)

            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.errorMessage ?? "Loading block data...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(crtBrightText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(crtBlue)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(crtBorder, lineWidth: 2)
                )
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            VStack(spacing: 0) {
                Divider()
                    .padding(.vertical, 6)

                MenuButton(
                    icon: "arrow.clockwise",
                    title: store.isFetching ? "Refreshing…" : "Refresh Now",
                    disabled: store.isFetching
                ) {
                    Task { await store.refresh() }
                }

                Divider()
                    .padding(.vertical, 4)

                Menu {
                    Menu("Refresh every: \(settings.refreshInterval.label)") {
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
                    Menu("Icon style: \(settings.iconStyle.label)") {
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
            .padding(.bottom, 6)
        }
        .frame(width: 280)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
    }

    private func timeAgoSimple(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
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
