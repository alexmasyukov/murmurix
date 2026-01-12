//
//  SettingsView.swift
//  Murmurix
//

import SwiftUI

struct SettingsView: View {
    @Binding var isDaemonRunning: Bool

    var onDaemonToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey, Hotkey) -> Void)?
    var onModelChanged: (() -> Void)?

    init(
        isDaemonRunning: Binding<Bool>,
        onDaemonToggle: ((Bool) -> Void)? = nil,
        onHotkeysChanged: ((Hotkey, Hotkey, Hotkey) -> Void)? = nil,
        onModelChanged: (() -> Void)? = nil
    ) {
        self._isDaemonRunning = isDaemonRunning
        self.onDaemonToggle = onDaemonToggle
        self.onHotkeysChanged = onHotkeysChanged
        self.onModelChanged = onModelChanged
    }

    var body: some View {
        GeneralSettingsView(
            isDaemonRunning: $isDaemonRunning,
            onDaemonToggle: onDaemonToggle,
            onHotkeysChanged: onHotkeysChanged,
            onModelChanged: onModelChanged
        )
        .frame(minWidth: 480, minHeight: 380)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView(isDaemonRunning: .constant(true))
}
