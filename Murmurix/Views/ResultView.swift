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

    @State private var lastKeyPress: String = "—"

    var body: some View {
        VStack(spacing: 0) {
            // Header with debug label and close button
            HStack {
                // Debug: last key press
                Text("Key: \(lastKeyPress)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.7))
                    .padding(.leading, 12)

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
            .background(
                KeyEventCatcher(onKeyPress: { key in
                    lastKeyPress = key
                })
            )

            // Text content - temporarily disabled for ESC debug
            // SelectableTextView(text: text)
            //     .padding(.horizontal, 16)
            //     .padding(.bottom, 8)

            // Placeholder
            Text(text)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

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

// MARK: - Key Event Catcher (for debugging)

struct KeyEventCatcher: NSViewRepresentable {
    let onKeyPress: (String) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.onKeyPress = onKeyPress
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyCatcherView: NSView {
        var onKeyPress: ((String) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                    self?.handleEvent(event)
                    return event
                }
            }
        }

        override func removeFromSuperview() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            super.removeFromSuperview()
        }

        private func handleEvent(_ event: NSEvent) {
            if event.type == .flagsChanged {
                var mods: [String] = []
                if event.modifierFlags.contains(.command) { mods.append("⌘") }
                if event.modifierFlags.contains(.option) { mods.append("⌥") }
                if event.modifierFlags.contains(.control) { mods.append("⌃") }
                if event.modifierFlags.contains(.shift) { mods.append("⇧") }
                onKeyPress?(mods.isEmpty ? "—" : mods.joined())
            } else {
                let keyName: String
                switch event.keyCode {
                case 53: keyName = "ESC"
                case 51: keyName = "⌫"
                case 36: keyName = "↩"
                case 48: keyName = "⇥"
                case 49: keyName = "Space"
                default:
                    if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                        keyName = chars.uppercased()
                    } else {
                        keyName = "[\(event.keyCode)]"
                    }
                }

                var mods: [String] = []
                if event.modifierFlags.contains(.command) { mods.append("⌘") }
                if event.modifierFlags.contains(.option) { mods.append("⌥") }
                if event.modifierFlags.contains(.control) { mods.append("⌃") }
                if event.modifierFlags.contains(.shift) { mods.append("⇧") }

                let fullKey = mods.isEmpty ? keyName : mods.joined() + keyName
                onKeyPress?(fullKey)
            }
        }
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
