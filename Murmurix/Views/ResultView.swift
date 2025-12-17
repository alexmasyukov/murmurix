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

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
                .contentShape(Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
            .padding(.bottom, 4)

            // Text content - selectable textarea
            SelectableTextView(text: text)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Bottom toolbar
            HStack(spacing: 0) {
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)

                Spacer()

                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Text(formattedDuration)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Copy button
                Button(action: copyAndClose) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: 420, height: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
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
