//
//  HotkeyRecorderView.swift
//  Murmurix
//

import SwiftUI
import Carbon

struct HotkeyRecorderView: View {
    let title: String
    let description: String?
    @Binding var hotkey: Hotkey?
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?
    @AppStorage("appLanguage") private var appLanguage = "en"

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Layout.Spacing.tiny) {
                Text(title)
                    .font(Typography.label)
                    .foregroundColor(.white)
                if let description, !description.isEmpty {
                    Text(description)
                        .font(Typography.description)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: { toggleRecording() }) {
                    HStack(spacing: 4) {
                        if isRecording {
                            Text(L10n.pressKeys)
                                .font(Typography.monospaced)
                                .foregroundColor(.gray)
                        } else if let hotkey {
                            ForEach(hotkey.displayParts, id: \.self) { part in
                                KeyCapView(text: part)
                            }
                        } else {
                            Text(L10n.notSet)
                                .font(Typography.monospaced)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.item)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.button)
                            .fill(isRecording ? Color.accentColor.opacity(0.3) : AppColors.divider)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.button)
                            .stroke(isRecording ? Color.accentColor : AppColors.subtleBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if hotkey != nil {
                    Button(action: { hotkey = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)

        // Convert NSEvent modifiers to Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        DispatchQueue.main.async {
            self.hotkey = Hotkey(keyCode: keyCode, modifiers: carbonModifiers)
            self.stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true

        // Disable global hotkey interception while recording new hotkey
        GlobalHotkeyManager.isRecordingHotkey = true

        // Local monitor - when app is in focus
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
            return nil // consume event
        }

        // Global monitor - when app is not in focus
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
        }
    }

    private func stopRecording() {
        isRecording = false

        // Re-enable global hotkey interception
        GlobalHotkeyManager.isRecordingHotkey = false

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
}

struct KeyCapView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, Layout.Spacing.indicator)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.buttonBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppColors.subtleBorder, lineWidth: 0.5)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        HotkeyRecorderView(
            title: "Cloud Recording",
            description: "Record with OpenAI cloud",
            hotkey: .constant(Hotkey(keyCode: 2, modifiers: UInt32(controlKey)))
        )

        HotkeyRecorderView(
            title: "Cancel Recording",
            description: "Discards the active recording",
            hotkey: .constant(nil)
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
