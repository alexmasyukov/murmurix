//
//  RecordingTimer.swift
//  Murmurix
//

import Foundation
import Combine

class RecordingTimer: ObservableObject {
    @Published var elapsedSeconds: Int = 0
    private var timer: Timer?

    func start() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
