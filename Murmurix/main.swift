//
//  main.swift
//  Murmurix
//

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate(dependencies: .live())
app.delegate = delegate
app.setActivationPolicy(.accessory)  // Menu bar only, no Dock icon
app.run()
