//
//  SettingsView.swift
//  Murmurix
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("keepDaemonRunning") private var keepDaemonRunning = true
    @AppStorage("language") private var language = "ru"

    @State private var toggleHotkey: Hotkey
    @State private var cancelHotkey: Hotkey

    var onDaemonToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey) -> Void)?

    init(onDaemonToggle: ((Bool) -> Void)? = nil, onHotkeysChanged: ((Hotkey, Hotkey) -> Void)? = nil) {
        self.onDaemonToggle = onDaemonToggle
        self.onHotkeysChanged = onHotkeysChanged

        // Load saved hotkeys
        _toggleHotkey = State(initialValue: HotkeySettings.loadToggleHotkey())
        _cancelHotkey = State(initialValue: HotkeySettings.loadCancelHotkey())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Keyboard Shortcuts Section
            SectionHeader(title: "Keyboard Shortcuts")

            VStack(spacing: 0) {
                HotkeyRecorderView(
                    title: "Toggle Recording",
                    description: "Starts and stops recordings",
                    hotkey: $toggleHotkey
                )
                .onChange(of: toggleHotkey) { _, newValue in
                    HotkeySettings.saveToggleHotkey(newValue)
                    onHotkeysChanged?(newValue, cancelHotkey)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 16)

                HotkeyRecorderView(
                    title: "Cancel Recording",
                    description: "Discards the active recording",
                    hotkey: $cancelHotkey
                )
                .onChange(of: cancelHotkey) { _, newValue in
                    HotkeySettings.saveCancelHotkey(newValue)
                    onHotkeysChanged?(toggleHotkey, newValue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)

            // Performance Section
            SectionHeader(title: "Performance")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep model in memory")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    Text("Faster transcription, uses ~500MB RAM")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $keepDaemonRunning)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: keepDaemonRunning) { _, newValue in
                        onDaemonToggle?(newValue)
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)

            // Recognition Section
            SectionHeader(title: "Recognition")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Language")
                        .font(.system(size: 13))
                        .foregroundColor(.white)

                    Spacer()

                    Picker("", selection: $language) {
                        Text("Russian").tag("ru")
                        Text("English").tag("en")
                        Text("Auto-detect").tag("auto")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 16)
        .frame(width: 380, height: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(.dark)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.gray)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}

// MARK: - Hotkey Settings Storage

struct HotkeySettings {
    private static let toggleKey = "toggleHotkey"
    private static let cancelKey = "cancelHotkey"

    static func loadToggleHotkey() -> Hotkey {
        if let data = UserDefaults.standard.data(forKey: toggleKey),
           let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) {
            return hotkey
        }
        return Hotkey.toggleDefault
    }

    static func saveToggleHotkey(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: toggleKey)
        }
    }

    static func loadCancelHotkey() -> Hotkey {
        if let data = UserDefaults.standard.data(forKey: cancelKey),
           let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) {
            return hotkey
        }
        return Hotkey.cancelDefault
    }

    static func saveCancelHotkey(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: cancelKey)
        }
    }
}

#Preview {
    SettingsView()
}
