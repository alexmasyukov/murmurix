//
//  ResultWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

class ResultWindowController: NSWindowController, NSWindowDelegate {

    convenience init(text: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Transcription Result"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 300, height: 200)
        window.appearance = NSAppearance(named: .darkAqua)

        self.init(window: window)
        window.delegate = self

        let contentView = ResultView(text: text)
        window.contentView = NSHostingView(rootView: contentView)
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Window controller will be released after close
    }
}
