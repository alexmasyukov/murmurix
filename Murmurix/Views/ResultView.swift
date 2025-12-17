//
//  ResultView.swift
//  Murmurix
//

import SwiftUI
import AppKit

struct ResultView: View {
    let text: String

    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                Text(text)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)

            HStack(spacing: 12) {
                Button(action: copyToClipboard) {
                    HStack {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                    .frame(width: 100)
                }
                .buttonStyle(.borderedProminent)

                Button(action: closeWindow) {
                    Text("Close")
                        .frame(width: 80)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 300)
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

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

#Preview {
    ResultView(text: "This is a sample transcription result.")
}
