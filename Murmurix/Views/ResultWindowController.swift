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

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
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
        super.showWindow(sender)
        if let window = window {
            WindowPositioner.centerAndActivate(window)
        }
    }
}
