//
//  ResultWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

class ResultWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

class ResultWindowController: NSWindowController {

    var onDelete: (() -> Void)?

    convenience init(text: String, duration: TimeInterval, onDelete: @escaping () -> Void) {
        let window = ResultWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        // Don't use isMovableByWindowBackground - it blocks button clicks

        let controller = ResultWindowController(window: window)
        controller.onDelete = onDelete

        window.onEscape = { [weak controller] in
            controller?.close()
        }

        let contentView = ResultView(
            text: text,
            duration: duration,
            onDelete: { [weak controller] in
                onDelete()
                controller?.close()
            },
            onClose: { [weak controller] in
                controller?.close()
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = .clear
        window.contentView = hostingView

        self.init(window: window)
        self.onDelete = onDelete
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
