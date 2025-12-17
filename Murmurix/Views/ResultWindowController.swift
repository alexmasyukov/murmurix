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
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Transcription Result"
        window.minSize = NSSize(width: 300, height: 200)

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
