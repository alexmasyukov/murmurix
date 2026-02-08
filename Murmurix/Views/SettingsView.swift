//
//  SettingsView.swift
//  Murmurix
//

import SwiftUI

struct SettingsView: View {
    @Binding var isModelLoaded: Bool

    var onModelToggle: ((Bool) -> Void)?
    var onHotkeysChanged: ((Hotkey, Hotkey, Hotkey, Hotkey) -> Void)?
    var onModelChanged: (() -> Void)?

    init(
        isModelLoaded: Binding<Bool>,
        onModelToggle: ((Bool) -> Void)? = nil,
        onHotkeysChanged: ((Hotkey, Hotkey, Hotkey, Hotkey) -> Void)? = nil,
        onModelChanged: (() -> Void)? = nil
    ) {
        self._isModelLoaded = isModelLoaded
        self.onModelToggle = onModelToggle
        self.onHotkeysChanged = onHotkeysChanged
        self.onModelChanged = onModelChanged
    }

    var body: some View {
        GeneralSettingsView(
            isModelLoaded: $isModelLoaded,
            onModelToggle: onModelToggle,
            onHotkeysChanged: onHotkeysChanged,
            onModelChanged: onModelChanged
        )
        .frame(minWidth: 480, minHeight: 380)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView(isModelLoaded: .constant(true))
}
