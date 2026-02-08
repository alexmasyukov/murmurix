//
//  WindowManager.swift
//  Murmurix
//

import AppKit

final class WindowManager {
    private var recordingController: RecordingWindowController?
    private var resultController: ResultWindowController?
    private var settingsController: SettingsWindowController?
    private var historyController: HistoryWindowController?

    // MARK: - Recording Window

    func showRecordingWindow(
        audioRecorder: AudioRecorder,
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
            historyController = HistoryWindowController()
        }
        historyController?.showWindow(nil)
    }

    // MARK: - Settings Window

    func showSettingsWindow(
        isModelLoaded: Bool,
        onModelToggle: @escaping (Bool) -> Void,
        onHotkeysChanged: @escaping (Hotkey, Hotkey, Hotkey, Hotkey) -> Void,
        onModelChanged: @escaping () -> Void,
        onWindowOpen: @escaping () -> Void,
        onWindowClose: @escaping () -> Void
    ) {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                isModelLoaded: isModelLoaded,
                onModelToggle: onModelToggle,
                onHotkeysChanged: onHotkeysChanged,
                onModelChanged: onModelChanged,
                onWindowOpen: onWindowOpen,
                onWindowClose: onWindowClose
            )
        } else {
            settingsController?.updateModelStatus(isModelLoaded)
            onWindowOpen()
        }
        settingsController?.showWindow(nil)
    }
}
