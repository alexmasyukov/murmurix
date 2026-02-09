//
//  WindowManager.swift
//  Murmurix
//

import AppKit

final class WindowManager {
    private let historyService: HistoryServiceProtocol
    private var recordingController: RecordingWindowController?
    private var resultController: ResultWindowController?
    private var settingsController: SettingsWindowController?
    private var historyController: HistoryWindowController?

    init(historyService: HistoryServiceProtocol) {
        self.historyService = historyService
    }

    // MARK: - Recording Window

    func showRecordingWindow(
        audioRecorder: any AudioRecorderProtocol,
        onStop: @escaping () -> Void,
        onCancelTranscription: @escaping () -> Void
    ) {
        recordingController = RecordingWindowController(
            audioRecorder: audioRecorder,
            onStop: onStop,
            onCancelTranscription: onCancelTranscription
        )
        recordingController?.showWindow(nil)
    }

    func showTranscribing() {
        recordingController?.showTranscribing()
    }

    func dismissRecordingWindow() {
        recordingController?.close()
        recordingController = nil
    }

    // MARK: - Result Window

    func showResultWindow(
        text: String,
        duration: TimeInterval,
        onDelete: @escaping () -> Void
    ) {
        resultController = ResultWindowController(
            text: text,
            duration: duration,
            onDelete: onDelete
        )
        resultController?.showWindow(nil)
    }

    // MARK: - History Window

    func showHistoryWindow() {
        if historyController == nil {
            historyController = HistoryWindowController(historyService: historyService)
        }
        historyController?.showWindow(nil)
    }

    // MARK: - Settings Window

    func showSettingsWindow(
        settings: SettingsStorageProtocol,
        loadedModels: Set<String>,
        onModelToggle: @escaping (String, Bool) -> Void,
        onLocalHotkeysChanged: @escaping ([String: Hotkey]) -> Void,
        onCloudHotkeysChanged: @escaping (Hotkey?, Hotkey?, Hotkey?) -> Void,
        onWindowOpen: @escaping () -> Void,
        onWindowClose: @escaping () -> Void
    ) {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                settings: settings,
                loadedModels: loadedModels,
                onModelToggle: onModelToggle,
                onLocalHotkeysChanged: onLocalHotkeysChanged,
                onCloudHotkeysChanged: onCloudHotkeysChanged,
                onWindowOpen: onWindowOpen,
                onWindowClose: onWindowClose
            )
        } else {
            settingsController?.updateLoadedModels(loadedModels)
            onWindowOpen()
        }
        settingsController?.showWindow(nil)
    }
}
