import SwiftUI
import Combine
import AppKit

struct BitcoinMenuView: View {
    @ObservedObject var store: BlockStore
    @ObservedObject var settings: SettingsStore
    private static let numberFormatter = makeNumberFormatter()
    private static let priceFormatter = makePriceFormatter()
    private static let dateFormatter = makeDateFormatter()
    private static let btcFormatter = makeBTCFormatter()
    private static let shortDateFormatter = makeShortDateFormatter()

    // Bitcoin orange/amber theme
    private let accentColor = Color.orange
    @State private var showBlockDetails = false
    @State private var isBlockHovered = false
    @State private var showPriceDetails = false
    @State private var isPriceHovered = false
    @State private var isSatsHovered = false

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
                                .fill(accentColor.opacity(isBlockHovered ? 0.35 : 0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(accentColor.opacity(isBlockHovered ? 0.45 : 0.18), lineWidth: 1)
                                )
                                .frame(width: 36, height: 36)
                            Text("₿")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(accentColor)
                        }
                        .shadow(color: accentColor.opacity(isBlockHovered ? 0.35 : 0), radius: 6, x: 0, y: 0)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Block #\(Self.formatNumber(block.height))")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Text("\(Self.timeAgoSimple(from: date, now: now)) ago")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Self.formatNumber(block.txCount))")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            Text("txns")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture {
                        showBlockDetails.toggle()
                    }
                    .onHover { hovering in
                        isBlockHovered = hovering
                    }
                    .popover(isPresented: $showBlockDetails, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
                        BlockDetailPopover(
                            block: block,
                            snapshot: snapshot,
                            now: now,
                            accentColor: accentColor
                        )
                    }
                }

                // Price & Sats Row
                HStack(spacing: 6) {
                    if let price = snapshot.priceUSD {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Price")
                                    .font(.system(size: 9))
                                    .foregroundStyle(isPriceHovered ? accentColor : .secondary)
                                    .shadow(color: accentColor.opacity(isPriceHovered ? 0.55 : 0), radius: 4, x: 0, y: 0)
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
                            Text("$\(Self.formatPrice(price))")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            showPriceDetails.toggle()
                        }
                        .onHover { hovering in
                            isPriceHovered = hovering
                        }
                        .overlay(alignment: .leading) {
                            AnchoredPopover(isPresented: $showPriceDetails, preferredEdge: .minX) {
                                PriceDetailPopover(
                                    price: price,
                                    details: snapshot.priceDetails,
                                    source: snapshot.priceSource,
                                    fetchedAt: snapshot.fetchedAt,
                                    now: now,
                                    accentColor: accentColor
                                )
                            }
                            .frame(width: 1, height: 1)
                            .offset(x: 62)
                        }
                    }

                    if snapshot.priceUSD != nil || snapshot.priceDetails?.currentPrice != nil {
                        let fiat = settings.fiatCurrency
                        let currentPrice = snapshot.priceDetails?.currentPrice?[fiat.rawValue]
                            ?? (fiat == .usd ? snapshot.priceUSD : nil)
                        let satsValue = currentPrice.map { Int((100_000_000 / $0).rounded()) }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fiat.satsLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(isSatsHovered ? accentColor : .secondary)
                                .shadow(color: accentColor.opacity(isSatsHovered ? 0.55 : 0), radius: 4, x: 0, y: 0)
                            Text(satsValue.map(Self.formatNumber) ?? "--")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            settings.cycleFiatCurrency()
                        }
                        .onHover { hovering in
                            isSatsHovered = hovering
                        }
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
                            FeeBox(label: "Low", value: Self.formatFee(fees.hourFee), color: .green)
                            FeeBox(label: "Med", value: Self.formatFee(fees.halfHourFee), color: .yellow)
                            FeeBox(label: "High", value: Self.formatFee(fees.fastestFee), color: .red)
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
                    Text("Updated \(Self.timeAgoSimple(from: snapshot.fetchedAt, now: now)) ago")
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
        .onChange(of: store.snapshot?.block?.id) { _ in
            showBlockDetails = false
        }
        .padding(8)
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }

    fileprivate static func formatNumber(_ number: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    fileprivate static func formatPrice(_ price: Double) -> String {
        Self.priceFormatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
    }

    fileprivate static func formatFee(_ fee: Double) -> String {
        let isWhole = abs(fee.rounded() - fee) < 0.0001
        if fee >= 10 {
            return String(format: isWhole ? "%.0f" : "%.1f", fee)
        } else if fee >= 1 {
            return String(format: isWhole ? "%.0f" : "%.1f", fee)
        } else {
            return String(format: "%.1f", fee)
        }
    }

    fileprivate static func timeAgoSimple(from date: Date, now: Date) -> String {
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

    fileprivate static func formatDateTime(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    fileprivate static func formatSize(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_000_000
        return String(format: "%.2f MB", mb)
    }

    fileprivate static func formatWeight(_ weight: Int) -> String {
        let mwu = Double(weight) / 1_000_000
        return String(format: "%.2f MWU", mwu)
    }

    fileprivate static func formatBTC(_ value: Double) -> String {
        let formatted = Self.btcFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)
        return "\(formatted) BTC"
    }

    fileprivate static func formatUSD(_ value: Double) -> String {
        "$\(Self.formatPrice(value))"
    }

    fileprivate static func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))%"
    }

    fileprivate static func formatFeeSpan(_ fees: [Double]) -> String {
        guard let minFee = fees.min(), let maxFee = fees.max() else { return "-" }
        return "\(formatFee(minFee)) - \(formatFee(maxFee)) sat/vB"
    }

    fileprivate static func shortHash(_ hash: String) -> String {
        guard hash.count > 16 else { return hash }
        let start = hash.prefix(6)
        let end = hash.suffix(6)
        return "\(start)...\(end)"
    }

    fileprivate static func blockSubsidyBTC(height: Int) -> Double {
        let halvings = height / 210_000
        if halvings >= 64 { return 0 }
        return 50.0 / pow(2.0, Double(halvings))
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

    private static func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private static func makeBTCFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return formatter
    }

    private static func makeShortDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }

    fileprivate static func formatShortDate(_ date: Date) -> String {
        Self.shortDateFormatter.string(from: date)
    }
}

private struct BlockDetailPopover: View {
    let block: BlockInfo
    let snapshot: BitcoinSnapshot
    let now: Date
    let accentColor: Color

    var body: some View {
        let blockDate = Date(timeIntervalSince1970: block.timestamp)
        let timeAgo = BitcoinMenuView.timeAgoSimple(from: blockDate, now: now)
        let feeRange = block.extras?.feeRange
        let medianFee = block.extras?.medianFee
        let totalFeesBTC = block.extras?.totalFeesBTC
        let rewardBTC = block.extras?.rewardBTC
        let priceUSD = snapshot.priceUSD

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Block details")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Text("#\(BitcoinMenuView.formatNumber(block.height))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)
            }

            Divider()

            BlockDetailRow(
                label: "Hash",
                value: BitcoinMenuView.shortHash(block.id),
                monospaced: true
            )

            BlockDetailRow(
                label: "Timestamp",
                value: BitcoinMenuView.formatDateTime(blockDate),
                subvalue: "(\(timeAgo) ago)"
            )

            BlockDetailRow(
                label: "Size",
                value: BitcoinMenuView.formatSize(block.size)
            )

            BlockDetailRow(
                label: "Weight",
                value: BitcoinMenuView.formatWeight(block.weight)
            )

            BlockDetailRow(
                label: "Transactions",
                value: BitcoinMenuView.formatNumber(block.txCount)
            )

            if let feeRange, !feeRange.isEmpty {
                BlockDetailRow(
                    label: "Fee span",
                    value: BitcoinMenuView.formatFeeSpan(feeRange)
                )
            }

            if let medianFee {
                BlockDetailRow(
                    label: "Median fee",
                    value: "~\(BitcoinMenuView.formatFee(medianFee)) sat/vB"
                )
            }

            if let totalFeesBTC {
                BlockDetailRow(
                    label: "Total fees",
                    value: BitcoinMenuView.formatBTC(totalFeesBTC),
                    subvalue: priceUSD.map { BitcoinMenuView.formatUSD($0 * totalFeesBTC) }
                )
            }

            if let rewardBTC {
                BlockDetailRow(
                    label: "Subsidy + fees",
                    value: BitcoinMenuView.formatBTC(rewardBTC),
                    subvalue: priceUSD.map { BitcoinMenuView.formatUSD($0 * rewardBTC) }
                )
            } else if let totalFeesBTC {
                let subsidy = BitcoinMenuView.blockSubsidyBTC(height: block.height)
                let totalReward = subsidy + totalFeesBTC
                BlockDetailRow(
                    label: "Subsidy + fees",
                    value: BitcoinMenuView.formatBTC(totalReward),
                    subvalue: priceUSD.map { BitcoinMenuView.formatUSD($0 * totalReward) }
                )
            }

            if let miner = block.extras?.poolName {
                BlockDetailRow(label: "Miner", value: miner)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}

private struct PriceDetailPopover: View {
    let price: Double
    let details: PriceDetails?
    let source: PriceSource?
    let fetchedAt: Date
    let now: Date
    let accentColor: Color

    var body: some View {
        let sparkline = details?.sparkline7d ?? []
        let last24 = Array(sparkline.suffix(24))
        let updatedAt = details?.lastUpdated ?? fetchedAt

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Price details")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Text("$\(BitcoinMenuView.formatPrice(price))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)
            }

            if !last24.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last 24h")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    SparklineView(values: last24, lineColor: accentColor)
                        .frame(height: 36)
                }
            }

            Divider()

            if details != nil {
                PriceDeltaRow(label: "24h change", value: details?.change24h)
                PriceDeltaRow(label: "7d change", value: details?.change7d)
                PriceDeltaRow(label: "30d change", value: details?.change30d)

                if let low = details?.low24h, let high = details?.high24h {
                    BlockDetailRow(
                        label: "24h range",
                        value: "\(BitcoinMenuView.formatUSD(low)) - \(BitcoinMenuView.formatUSD(high))"
                    )
                }

                if let ath = details?.ath {
                    BlockDetailRow(
                        label: "ATH",
                        value: BitcoinMenuView.formatUSD(ath),
                        subvalue: details?.athDate.map { BitcoinMenuView.formatShortDate($0) }
                    )
                }

            } else {
                Text("Additional price details unavailable.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            BlockDetailRow(
                label: "Source",
                value: source?.label ?? "Unknown"
            )

            BlockDetailRow(
                label: "Updated",
                value: "\(BitcoinMenuView.timeAgoSimple(from: updatedAt, now: now)) ago"
            )

            if let source {
                Button {
                    let urlString = source == .coinGecko
                        ? "https://www.coingecko.com/en/coins/bitcoin"
                        : "https://mempool.space"
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 9))
                        Text(source == .coinGecko ? "Open CoinGecko" : "Open mempool.space")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}

private struct SparklineView: View {
    let values: [Double]
    let lineColor: Color

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2, let minValue = values.min(), let maxValue = values.max() {
                let range = max(maxValue - minValue, 0.0001)
                Path { path in
                    for index in values.indices {
                        let x = geo.size.width * CGFloat(index) / CGFloat(values.count - 1)
                        let y = geo.size.height * (1 - CGFloat((values[index] - minValue) / range))
                        if index == values.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, lineWidth: 1.4)
            }
        }
    }
}

private struct PriceDeltaRow: View {
    let label: String
    let value: Double?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
            if let value {
                Text(BitcoinMenuView.formatPercent(value))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(value >= 0 ? .green : .red)
            } else {
                Text("--")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AnchoredPopover<PopoverContent: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    var preferredEdge: NSRectEdge = .minX
    let content: () -> PopoverContent

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented {
            if context.coordinator.popover == nil {
                let popover = NSPopover()
                popover.behavior = .transient
                popover.delegate = context.coordinator
                popover.contentViewController = NSHostingController(rootView: content())
                context.coordinator.popover = popover
            } else if let hosting = context.coordinator.popover?.contentViewController as? NSHostingController<PopoverContent> {
                hosting.rootView = content()
            } else {
                context.coordinator.popover?.contentViewController = NSHostingController(rootView: content())
            }

            if context.coordinator.popover?.isShown == false {
                context.coordinator.popover?.show(relativeTo: nsView.bounds, of: nsView, preferredEdge: preferredEdge)
            }
        } else {
            context.coordinator.popover?.performClose(nil)
        }
    }

    final class Coordinator: NSObject, NSPopoverDelegate {
        var parent: AnchoredPopover
        var popover: NSPopover?

        init(parent: AnchoredPopover) {
            self.parent = parent
        }

        func popoverDidClose(_ notification: Notification) {
            parent.isPresented = false
            popover = nil
        }
    }
}

private struct BlockDetailRow: View {
    let label: String
    let value: String
    var subvalue: String? = nil
    var monospaced: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 10, weight: .semibold, design: monospaced ? .monospaced : .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let subvalue {
                HStack {
                    Spacer()
                    Text(subvalue)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
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
