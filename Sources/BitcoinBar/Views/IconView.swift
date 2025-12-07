import SwiftUI
import AppKit

struct IconView: View {
    let snapshot: BitcoinSnapshot?
    let isStale: Bool
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Image(nsImage: makeIcon())
    }

    private func makeIcon() -> NSImage {
        switch settings.iconStyle {
        case .bitcoinSymbol:
            return makeBitcoinSymbolIcon()
        case .blockHeight:
            return makeBlockHeightIcon()
        }
    }

    private func makeBitcoinSymbolIcon() -> NSImage {
        let size = NSSize(width: 20, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let iconColor = NSColor.labelColor.withAlphaComponent(isStale ? 0.5 : 1.0)

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let bitcoinSymbol = NSImage(systemSymbolName: "bitcoinsign.circle.fill", accessibilityDescription: "Bitcoin") {
            let symbolImage = bitcoinSymbol.withSymbolConfiguration(symbolConfig) ?? bitcoinSymbol

            let symbolSize = symbolImage.size
            let x = (size.width - symbolSize.width) / 2
            let y = (size.height - symbolSize.height) / 2

            iconColor.set()
            symbolImage.draw(at: NSPoint(x: x, y: y), from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: iconColor
            ]
            let text = "₿"
            let textSize = text.size(withAttributes: attributes)
            let x = (size.width - textSize.width) / 2
            let y = (size.height - textSize.height) / 2
            text.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func makeBlockHeightIcon() -> NSImage {
        let formattedNumber: String
        if let height = snapshot?.block?.height {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formattedNumber = formatter.string(from: NSNumber(value: height)) ?? String(height)
        } else {
            formattedNumber = "---"
        }

        let text = "₿\(formattedNumber)"
        let fontSize: CGFloat = 11
        let iconColor = NSColor.labelColor.withAlphaComponent(isStale ? 0.5 : 1.0)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: iconColor
        ]

        let textSize = text.size(withAttributes: attributes)
        let width = textSize.width + 4
        let height: CGFloat = 18

        let size = NSSize(width: max(width, 20), height: height)
        let image = NSImage(size: size)
        image.lockFocus()

        let x = (size.width - textSize.width) / 2
        let y = (size.height - textSize.height) / 2

        text.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
