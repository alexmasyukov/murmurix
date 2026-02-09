//
//  HistoryWindowController.swift
//  Murmurix
//

import Cocoa
import SwiftUI

@MainActor
class HistoryWindowController: NSWindowController, NSWindowDelegate {

    private let historyViewModel: HistoryViewModel
    private var languageObserver: NSObjectProtocol?

    init(historyService: HistoryServiceProtocol) {
        self.historyViewModel = HistoryViewModel(historyService: historyService)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.historyTitle
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 500, height: 300)
        window.appearance = NSAppearance(named: .darkAqua)

        super.init(window: window)
        window.delegate = self

        let contentView = HistoryView(viewModel: historyViewModel)
        window.contentView = NSHostingView(rootView: contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        window?.title = L10n.historyTitle
        startObservingLanguageChangesIfNeeded()
        historyViewModel.loadRecords()
        window?.center()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        stopObservingLanguageChanges()
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
            self.languageObserver = nil
        }
    }

    private func startObservingLanguageChangesIfNeeded() {
        guard languageObserver == nil else { return }
        languageObserver = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange, object: nil, queue: .main
        ) { [weak window] _ in
            window?.title = L10n.historyTitle
        }
    }

    private func stopObservingLanguageChanges() {
        guard let languageObserver else { return }
        NotificationCenter.default.removeObserver(languageObserver)
        self.languageObserver = nil
    }
}
