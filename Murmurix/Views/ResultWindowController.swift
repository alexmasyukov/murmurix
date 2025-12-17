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

    // Try both methods
    override func cancelOperation(_ sender: Any?) {
        print("cancelOperation called")
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        print("keyDown: \(event.keyCode)")
        if event.keyCode == 53 { // ESC
            print("ESC detected in keyDown")
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

class ResultWindowController: NSWindowController {

    private var onDeleteCallback: (() -> Void)?

    init(text: String, duration: TimeInterval, onDelete: @escaping () -> Void) {
        self.onDeleteCallback = onDelete

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

        super.init(window: window)

        // Set ESC handler
        window.onEscape = { [weak self] in
            self?.close()
        }

        // Now self is valid, create content view with correct references
        let contentView = ResultView(
            text: text,
            duration: duration,
            onDelete: { [weak self] in
                self?.onDeleteCallback?()
                self?.close()
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = .clear
        window.contentView = hostingView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
