//
//  ClaudeCodev2App.swift
//  ClaudeCodev2
//
//  Created by Felix Leber on 10.08.25.
//

import SwiftUI
import Cocoa

@main
struct ClaudeCodev2App: App {
    @StateObject private var controllerManager = ControllerManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controllerManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 APP: Application launching...")
        AppDelegate.shared = self
        
        // Create status bar item for background operation
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "🎮"
            button.toolTip = "ClaudeController - DualSense Integration"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        // Show window on first launch and keep it visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.setActivationPolicy(.regular)
            self.showWindow()
        }
        
        print("🚀 APP: Launch complete")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Switch to accessory mode when window is closed
        print("🪟 APP: Window closed, switching to background mode")
        NSApplication.shared.setActivationPolicy(.accessory)
        return false
    }
    
    @objc func showWindow() {
        print("🪟 APP: Showing window...")
        
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Find and show the main window
        if let window = NSApplication.shared.windows.first {
            print("🪟 APP: Found window, bringing to front")
            window.makeKeyAndOrderFront(nil)
            window.center()
        } else {
            print("⚠️ APP: No window found")
            
            // Force create a new window if none exists
            if let mainWindow = NSApplication.shared.mainWindow {
                mainWindow.makeKeyAndOrderFront(nil)
            }
        }
    }
}
