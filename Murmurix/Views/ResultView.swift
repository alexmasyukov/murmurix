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

    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
                .contentShape(Circle())
            }
            .padding(.top, 14)
            .padding(.trailing, 14)
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
                Button(action: copyToClipboard) {
                    HStack(spacing: 5) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(copied ? "Copied" : "Copy")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(copied ? .green : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(copied ? Color.green.opacity(0.2) : Color.white.opacity(0.15))
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

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

// MARK: - Selectable Text View (NSTextView wrapper)

struct SelectableTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay

        if let textView = scrollView.documentView as? NSTextView {
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
        }

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
