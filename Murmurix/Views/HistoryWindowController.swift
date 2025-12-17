//
//  HistoryWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

class HistoryWindowController: NSWindowController, NSWindowDelegate {

    private var historyViewModel = HistoryViewModel()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Transcription History"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 500, height: 300)
        window.appearance = NSAppearance(named: .darkAqua)

        self.init(window: window)
        window.delegate = self

        let contentView = HistoryView(viewModel: historyViewModel)
        window.contentView = NSHostingView(rootView: contentView)
    }

    override func showWindow(_ sender: Any?) {
        historyViewModel.loadRecords()
        window?.center()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
