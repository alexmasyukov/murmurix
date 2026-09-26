//
//  AudioRecorder.swift
//  Murmurix
//

import Foundation
import AVFoundation
import CoreAudio

/// Detects a *dead* input stream from meter readings taken while recording.
///
/// A dead stream (CoreAudio delivering all-zero buffers) meters at -120…-160 dB;
/// a quiet room's noise floor stays far above that (~-40…-60 dB), and a natural
/// pause in speech is room noise, not zeros. So `deadPowerThreshold` cleanly
/// separates "the user stopped talking" from "the microphone stopped delivering" —
/// the failure the user experiences as the equalizer going flat mid-sentence while
/// the recording length stays intact (zeros are still samples, so the capture
/// deficit reads ~0 even though speech in the window is gone).
struct InputDropoutDetector {
    /// Average power (dB) at or below which a meter tick counts as dead input.
    static let deadPowerThreshold: Float = -90

    /// Consecutive dead ticks before a dropout is declared (debounces one-off
    /// metering hiccups). 4 ticks at the 0.05s meter interval = 0.2s.
    static let minConsecutiveDeadTicks = 4

    private(set) var dropoutCount = 0
    private(set) var totalDeadTicks = 0
    private(set) var isInDropout = false
    private var consecutiveDeadTicks = 0

    enum Event: Equatable {
        case started
        case ended(deadTicks: Int)
    }

    /// Feed one meter reading; returns an event when a dropout starts or ends.
    mutating func tick(power: Float) -> Event? {
        if power <= Self.deadPowerThreshold {
            consecutiveDeadTicks += 1
            if !isInDropout && consecutiveDeadTicks == Self.minConsecutiveDeadTicks {
                isInDropout = true
                dropoutCount += 1
                return .started
            }
            return nil
        }

        defer { consecutiveDeadTicks = 0 }
        if isInDropout {
            isInDropout = false
            totalDeadTicks += consecutiveDeadTicks
            return .ended(deadTicks: consecutiveDeadTicks)
        }
        return nil
    }

    /// Closes out an in-flight dropout at stop time (so its ticks are counted).
    mutating func finish() {
        if isInDropout {
            totalDeadTicks += consecutiveDeadTicks
            isInDropout = false
        }
        consecutiveDeadTicks = 0
    }
}

/// Reads and watches the system default input device, so recordings can be
/// correlated with device switches (macOS re-routing to AirPods mid-dictation is
/// a classic cause of an input stream going quiet or dead).
enum DefaultAudioInput {
    static var deviceName: String {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = defaultInputAddress
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != 0 else { return "unknown" }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        let nameStatus = withUnsafeMutablePointer(to: &cfName) { pointer in
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, pointer)
        }
        guard nameStatus == noErr else { return "unknown" }
        return cfName as String
    }

    private static var defaultInputAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    /// Registers a listener for default-input-device changes. Returns a token
    /// closure that unregisters it.
    static func observeChanges(_ onChange: @escaping () -> Void) -> () -> Void {
        var address = defaultInputAddress
        let block: AudioObjectPropertyListenerBlock = { _, _ in onChange() }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block
        )
        return {
            var removeAddress = defaultInputAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &removeAddress, DispatchQueue.main, block
            )
        }
    }
}

class AudioRecorder: NSObject, ObservableObject, AudioRecorderProtocol {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var hadVoiceActivity = false

    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var levelTimer: Timer?
    /// Wall-clock moment record() returned true; used to compute the capture
    /// deficit (audio the hardware never delivered) at stop.
    private var recordingStartDate: Date?

    /// Dead-input detection for the current recording. See InputDropoutDetector.
    private var dropoutDetector = InputDropoutDetector()

    /// Unregisters the default-input-device listener.
    private var stopObservingInputDevice: (() -> Void)?

    override init() {
        super.init()
        // Log device switches for the app's lifetime: a mid-dictation re-route
        // (AirPods connecting, a USB mic waking) is the prime suspect whenever the
        // input goes flat, and without a timestamped log line it's unprovable.
        stopObservingInputDevice = DefaultAudioInput.observeChanges { [weak self] in
            guard let self else { return }
            let name = DefaultAudioInput.deviceName
            Logger.Audio.error("Default input device changed to: \(name)\(self.isRecording ? " — DURING an active recording" : "")")

            // The pre-primed recorder bound its audio queue when it was prepared —
            // possibly hours ago, to a device that is now gone or asleep. Recording
            // through it can yield a dead stream. Rebuild it against the new device.
            if !self.isRecording, self.preparedRecorder != nil {
                Logger.Audio.info("Re-priming recorder for the new input device")
                self.preparedRecorder = nil
                if let staleURL = self.preparedURL {
                    try? FileManager.default.removeItem(at: staleURL)
                    self.preparedURL = nil
                }
                self.prepare()
            }
        }
    }

    deinit {
        stopObservingInputDevice?()
    }

    /// A recorder built and prepared ahead of the hotkey press. See `prepare()`.
    private var preparedRecorder: AVAudioRecorder?
    private var preparedURL: URL?

    private let voiceActivityThreshold: Float = AudioConfig.voiceActivityThreshold

    // WAV format settings - high quality for better listening
    // Whisper will downsample to 16kHz internally
    private static let recorderSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 44100,  // CD quality for better listening
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
    ]

    // MARK: - Permission Handling

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
    }

    var permissionStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            self.runOnMain {
                completion(granted)
            }
        }
    }

    private func makeRecordingURL() -> URL {
        let fileName = "murmurix_recording_\(Date().timeIntervalSince1970).wav"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    /// Deletes recordings left in the temp directory by previous runs. The normal
    /// flow removes every file right after transcription; leftovers appear only
    /// when the app quit or crashed mid-flight, or from the pre-primed recorder's
    /// stub file (prepareToRecord() creates it). Call once at launch, before
    /// `prepare()` creates the stub for this run.
    ///
    /// Only files older than `minAge` are removed. The temp directory is shared
    /// with any *other* live Murmurix process — a second instance during an app
    /// update, or the test host (the test suite runs inside Murmurix.app, so its
    /// launch executes this sweep too). Deleting a fresh file out from under that
    /// process leaves its AVAudioRecorder writing into an unlinked inode: recording
    /// "works" but the path no longer exists when transcription tries to read it
    /// ("Resource path does not exist"). Crash leftovers are old by the next
    /// launch, so the age guard costs nothing.
    static func sweepStaleRecordings(
        in directory: URL = FileManager.default.temporaryDirectory,
        olderThan minAge: TimeInterval = 3600
    ) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-minAge)
        var removed = 0
        for url in files where url.lastPathComponent.hasPrefix("murmurix_recording_") {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            guard let modified, modified < cutoff else { continue }
            do {
                try fileManager.removeItem(at: url)
                removed += 1
            } catch {
                Logger.Audio.error("Failed to sweep stale recording \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if removed > 0 {
            Logger.Audio.info("Swept \(removed) stale recording file(s) from temp directory")
        }
    }

    /// Builds and primes the recorder for the *next* recording, so the hotkey press
    /// only has to call `record()`. Creating the AVAudioRecorder and letting
    /// `record()` do the file + audio-queue setup itself costs ~80ms of speech that
    /// is simply never captured; pre-primed, the same call returns in ~25ms.
    /// `prepareToRecord()` does not open the input, so no microphone indicator
    /// appears and nothing is captured until `record()` is actually called.
    func prepare() {
        guard permissionStatus == .granted, preparedRecorder == nil else { return }

        let url = makeRecordingURL()
        do {
            let recorder = try AVAudioRecorder(url: url, settings: Self.recorderSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord() else {
                Logger.Audio.error("prepareToRecord() failed; falling back to cold start")
                try? FileManager.default.removeItem(at: url)
                return
            }
            preparedRecorder = recorder
            preparedURL = url
        } catch {
            Logger.Audio.error("Failed to prepare recorder: \(error)")
        }
    }

    func startRecording() {
        // Check permission first
        guard permissionStatus == .granted else {
            if permissionStatus == .notDetermined {
                requestPermission { [weak self] granted in
                    if granted {
                        self?.startRecording()
                    } else {
                        Logger.Audio.error("Microphone permission denied")
                    }
                }
            } else {
                Logger.Audio.error("Microphone permission denied. Please enable in System Settings > Privacy > Microphone")
            }
            return
        }

        // Use the recorder primed after the last recording; only build one here if
        // the warm-up never ran (first launch before prepare(), or it failed).
        // If the prepared stub file vanished from disk (another Murmurix process —
        // an updater's second instance or the test host — swept the temp directory),
        // the warm recorder would happily record into the unlinked inode and the
        // path would not exist at transcription time. Fall back to a cold start.
        var warm = preparedRecorder
        var fileURL = preparedURL ?? makeRecordingURL()
        if let preparedURL, !FileManager.default.fileExists(atPath: preparedURL.path) {
            Logger.Audio.error("Prepared recording file vanished, falling back to cold start: \(preparedURL.path)")
            warm = nil
            fileURL = makeRecordingURL()
        }
        preparedRecorder = nil
        preparedURL = nil
        currentRecordingURL = fileURL

        do {
            if let warm {
                audioRecorder = warm
            } else {
                audioRecorder = try AVAudioRecorder(url: fileURL, settings: Self.recorderSettings)
                audioRecorder?.delegate = self
                audioRecorder?.isMeteringEnabled = true
            }
            // AVAudioRecorder.record() returns false when AVFoundation cannot
            // open the input stream — most often this happens when TCC says
            // the app is allowed but the underlying audio plumbing is stale
            // after the .app bundle was replaced in /Applications/. Symptom:
            // mic indicator never appears and meter values stay at zero.
            // Without checking the return value we'd happily log "Recording
            // started" and the user would see no waveform with no error.
            let recordStart = Date()
            let started = audioRecorder?.record() ?? false
            let recordLatencyMs = Date().timeIntervalSince(recordStart) * 1000
            guard started else {
                Logger.Audio.error("AVAudioRecorder.record() returned false — TCC state may be stale. Reset Microphone for Murmurix in System Settings.")
                audioRecorder = nil
                currentRecordingURL = nil
                return
            }
            isRecording = true
            hadVoiceActivity = false  // Reset voice activity flag
            recordingStartDate = Date()
            dropoutDetector = InputDropoutDetector()

            // Start monitoring audio levels
            startLevelMonitoring()

            Logger.Audio.info("Recording started in \(String(format: "%.0f", recordLatencyMs))ms (warm: \(warm != nil), input: \(DefaultAudioInput.deviceName)): \(fileURL.path)")
        } catch {
            Logger.Audio.error("Failed to start recording: \(error)")
        }
    }

    func stopRecording() -> URL {
        stopLevelMonitoring()
        // currentTime is how much audio the recorder actually captured. Compared
        // with wall-clock time it exposes the capture deficit: input-hardware
        // spin-up at the start (speech during that window is simply never
        // recorded) or a dropped tail buffer at the end.
        let capturedSeconds = audioRecorder?.currentTime ?? 0
        let wallSeconds = recordingStartDate.map { Date().timeIntervalSince($0) } ?? 0
        let deficitSeconds = wallSeconds - capturedSeconds
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        audioLevel = 0.0
        recordingStartDate = nil
        Logger.Audio.info(
            "Recording stopped: captured \(String(format: "%.2f", capturedSeconds))s of \(String(format: "%.2f", wallSeconds))s wall (deficit \(String(format: "%.2f", deficitSeconds))s): \(currentRecordingURL?.path ?? "unknown")"
        )
        if deficitSeconds > 0.3 {
            Logger.Audio.error(
                "Capture deficit \(String(format: "%.2f", deficitSeconds))s — the microphone came up late or dropped audio; speech in that window was never recorded"
            )
        }
        dropoutDetector.finish()
        if dropoutDetector.dropoutCount > 0 {
            let deadSeconds = Double(dropoutDetector.totalDeadTicks) * AudioConfig.meterUpdateInterval
            Logger.Audio.error(
                "This recording had \(dropoutDetector.dropoutCount) input dropout(s), \(String(format: "%.1f", deadSeconds))s of dead audio total (input: \(DefaultAudioInput.deviceName))"
            )
        }

        // Prime the next recorder once this turn of the run loop is done, so the
        // warm-up cost lands between recordings instead of inside stop().
        DispatchQueue.main.async { [weak self] in self?.prepare() }

        return currentRecordingURL ?? URL(fileURLWithPath: "")
    }

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: AudioConfig.meterUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }

            recorder.updateMeters()

            // Get average power in dB (range: -160 to 0)
            let avgPower = recorder.averagePower(forChannel: 0)

            // Dead-input watchdog: all-zero buffers meter at -120…-160 dB, far
            // below any real room. The user sees this as the equalizer going flat
            // mid-sentence; speech in the window is silently lost while the file
            // keeps growing (zeros are samples too, so the capture deficit stays 0).
            switch self.dropoutDetector.tick(power: avgPower) {
            case .started:
                Logger.Audio.error("Input went DEAD mid-recording (meter \(String(format: "%.0f", avgPower))dB, input: \(DefaultAudioInput.deviceName)) — microphone stopped delivering audio")
            case .ended(let deadTicks):
                let seconds = Double(deadTicks) * AudioConfig.meterUpdateInterval
                Logger.Audio.error("Input recovered after \(String(format: "%.1f", seconds))s dead — speech in that window was lost")
            case nil:
                break
            }

            // Convert to 0-1 range with some smoothing
            // -50 dB = silence, 0 dB = max
            let normalizedLevel = max(0, (avgPower + 50) / 50)

            self.runOnMain {
                // Smooth the transition
                self.audioLevel = self.audioLevel * 0.3 + normalizedLevel * 0.7

                // Track voice activity
                if self.audioLevel > self.voiceActivityThreshold {
                    self.hadVoiceActivity = true
                }
            }
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            Task { @MainActor in
                block()
            }
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Logger.Audio.error("Recording finished unsuccessfully")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            Logger.Audio.error("Recording encode error: \(error)")
        }
    }
}
