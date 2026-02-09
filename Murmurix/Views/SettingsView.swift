//
//  SettingsView.swift
//  Murmurix
//

import SwiftUI

struct SettingsView: View {
    let settings: SettingsStorageProtocol
    @Binding var loadedModels: Set<String>

    var onModelToggle: ((String, Bool) -> Void)?
    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?
    var onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)?

    init(
        settings: SettingsStorageProtocol = Settings.shared,
        loadedModels: Binding<Set<String>>,
        onModelToggle: ((String, Bool) -> Void)? = nil,
        onLocalHotkeysChanged: (([String: Hotkey]) -> Void)? = nil,
        onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)? = nil
    ) {
        self.settings = settings
        self._loadedModels = loadedModels
        self.onModelToggle = onModelToggle
        self.onLocalHotkeysChanged = onLocalHotkeysChanged
        self.onCloudHotkeysChanged = onCloudHotkeysChanged
    }

    var body: some View {
        GeneralSettingsView(
            settings: settings,
            loadedModels: $loadedModels,
            onModelToggle: onModelToggle,
            onLocalHotkeysChanged: onLocalHotkeysChanged,
            onCloudHotkeysChanged: onCloudHotkeysChanged
        )
        .frame(minWidth: 480, minHeight: 380)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView(loadedModels: .constant([]))
}
