//
//  ResultView.swift
//  Murmurix
//

import SwiftUI
import AppKit

struct ResultView: View {
    let text: String
    let duration: TimeInterval
    let onDelete: () -> Void
    let onClose: () -> Void
    @AppStorage("appLanguage") private var appLanguage = "en"

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(AppColors.mutedOpacity))
                        .frame(width: 24, height: 24)
                        .background(AppColors.divider)
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Layout.Spacing.section)
            .padding(.trailing, Layout.Spacing.section)
            .padding(.bottom, 4)

            // Text content - selectable textarea
            SelectableTextView(text: text)
                .padding(.horizontal, Layout.Padding.standard)
                .padding(.bottom, Layout.Spacing.item)

            // Bottom toolbar
            HStack(spacing: 0) {
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(Typography.monospaced)
                        .foregroundColor(.white.opacity(AppColors.mutedOpacity))
                        .frame(width: 32, height: 32)
                        .background(AppColors.buttonBackgroundSubtle)
                        .cornerRadius(Layout.Spacing.item)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(Typography.caption)
                        .foregroundColor(.white.opacity(0.4))
                    Text(formattedDuration)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(AppColors.disabledOpacity))
                }

                Spacer()

                // Copy button
                Button(action: copyAndClose) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                            .font(Typography.description)
                        Text(L10n.copy)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, Layout.Spacing.item)
                    .background(AppColors.buttonBackground)
                    .cornerRadius(Layout.Spacing.item)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, 14)
        }
        .frame(width: WindowSize.result.width, height: WindowSize.result.height)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.window)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.window)
                .strokeBorder(AppColors.divider, lineWidth: 1)
        )
    }

    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func copyAndClose() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        onClose()
    }
}

// MARK: - Selectable Text View (NSTextView wrapper)

// Custom NSTextView that passes ESC to the window
class PassthroughTextView: NSTextView {
    override func cancelOperation(_ sender: Any?) {
        // Pass ESC to window instead of handling it
        window?.cancelOperation(sender)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            window?.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }
}

struct SelectableTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay

        let textView = PassthroughTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = NSColor.white.withAlphaComponent(0.9)
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.isRichText = false
        textView.allowsUndo = false
        textView.focusRingType = .none
        textView.isAutomaticLinkDetectionEnabled = false
        textView.string = text

        // Setup for proper scrolling
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let textView = scrollView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
        }
    }
}

#Preview {
    ResultView(
        text: "Это пример распознанного текста, который показывает как будет выглядеть результат транскрипции в окне результата. Вы можете выделить любую часть текста и скопировать её.",
        duration: 125,
        onDelete: {},
        onClose: {}
    )
    .preferredColorScheme(.dark)
}
