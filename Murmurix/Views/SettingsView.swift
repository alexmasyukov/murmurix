//
//  SettingsView.swift
//  Murmurix
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("keepDaemonRunning") private var keepDaemonRunning = true
    @AppStorage("language") private var language = "ru"

    var onDaemonToggle: ((Bool) -> Void)?

    var body: some View {
        Form {
            Section {
                Toggle("Keep model in memory (faster)", isOn: $keepDaemonRunning)
                    .onChange(of: keepDaemonRunning) { _, newValue in
                        onDaemonToggle?(newValue)
                    }

                Text("When enabled, the speech recognition model stays loaded in memory for instant transcription. Uses ~500MB RAM.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Performance")
            }

            Section {
                Picker("Language", selection: $language) {
                    Text("Russian").tag("ru")
                    Text("English").tag("en")
                    Text("Auto-detect").tag("auto")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Recognition")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hotkeys")
                        .font(.headline)

                    HStack {
                        Text("Start recording:")
                        Spacer()
                        Text("Cmd + Shift + R")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Stop recording:")
                        Spacer()
                        Text("Cmd + Shift + S")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 280)
    }
}

#Preview {
    SettingsView()
}
