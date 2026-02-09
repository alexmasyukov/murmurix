//
//  SettingsView.swift
//  Murmurix
//

import SwiftUI

struct SettingsView: View {
    let settings: SettingsStorageProtocol
    let generalSettingsViewModel: GeneralSettingsViewModel
    @Binding var loadedModels: Set<String>

    var onModelToggle: ((String, Bool) -> Void)?
    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?
    var onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)?

    init(
        settings: SettingsStorageProtocol,
        generalSettingsViewModel: GeneralSettingsViewModel,
        loadedModels: Binding<Set<String>>,
        onModelToggle: ((String, Bool) -> Void)? = nil,
        onLocalHotkeysChanged: (([String: Hotkey]) -> Void)? = nil,
        onCloudHotkeysChanged: ((Hotkey?, Hotkey?, Hotkey?) -> Void)? = nil
    ) {
        self.settings = settings
        self.generalSettingsViewModel = generalSettingsViewModel
        self._loadedModels = loadedModels
        self.onModelToggle = onModelToggle
        self.onLocalHotkeysChanged = onLocalHotkeysChanged
        self.onCloudHotkeysChanged = onCloudHotkeysChanged
    }

    var body: some View {
        GeneralSettingsView(
            viewModel: generalSettingsViewModel,
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
    SettingsView(
        settings: Settings.shared,
        generalSettingsViewModel: GeneralSettingsViewModel.live(settings: Settings.shared),
        loadedModels: .constant([])
    )
}
