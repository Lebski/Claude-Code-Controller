import Cocoa
import CoreGraphics
import ApplicationServices

enum KeyAction {
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow
    case enter
    case x
    case autoAccept
    case escape
    case backspace
    case clearLine
    case scroll(deltaX: Double, deltaY: Double)
}

class KeyMapper {
    
    func checkAccessibilityPermissionOnStartup() -> Bool {
        let trusted = AXIsProcessTrusted()
        print("🔍 Startup permission check: \(trusted)")
        
        if !trusted {
            print("⚠️ Requesting accessibility permission on startup...")
            // Request permission with prompt
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            let result = AXIsProcessTrustedWithOptions(options)
            print("🔍 Permission request result: \(result)")
            
            // Wait a moment and check again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let recheckResult = AXIsProcessTrusted()
                print("🔍 Recheck after prompt: \(recheckResult)")
                if recheckResult {
                    NotificationCenter.default.post(name: Notification.Name("AccessibilityPermissionGranted"), object: nil)
                }
            }
        }
        
        return trusted
    }
    
    private func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func sendKeyPress(_ action: KeyAction) {
        NSLog("🔧 KEYMAPPER: sendKeyPress called with action: \(action)")
        
        // Check permission and update UI if needed
        if !hasAccessibilityPermission() {
            NSLog("⚠️ KEYMAPPER: No accessibility permission detected")
            NotificationCenter.default.post(name: Notification.Name("AccessibilityPermissionMissing"), object: nil)
        } else {
            NSLog("✅ KEYMAPPER: Accessibility permission confirmed")
        }
        
        NSLog("🎮 KEYMAPPER: Sending key press: \(action)")
        switch action {
        case .upArrow:
            simulateKeyPress(keyCode: 126) // Up arrow
        case .downArrow:
            simulateKeyPress(keyCode: 125) // Down arrow
        case .leftArrow:
            simulateKeyPress(keyCode: 123) // Left arrow (Delete)
        case .rightArrow:
            simulateKeyPress(keyCode: 124) // Right arrow (Enter)
        case .enter:
            simulateKeyPress(keyCode: 36) // Return key
        case .x:
            simulateKeyPress(keyCode: 53) // Escape key (Cancel)
        case .autoAccept:
            simulateKeyCombo(keyCode: 36, modifiers: .maskCommand) // Cmd+Enter
        case .escape:
            simulateKeyPress(keyCode: 53) // Escape
        case .backspace:
            simulateKeyPress(keyCode: 51) // Backspace/Delete
        case .clearLine:
            // Send 11 backspaces to clear input
            for _ in 0..<11 {
                simulateKeyPress(keyCode: 51) // Backspace
                Thread.sleep(forTimeInterval: 0.01)
            }
        case .scroll(let deltaX, let deltaY):
            simulateMouseScroll(deltaX: deltaX, deltaY: deltaY)
        }
    }
    
    func sendClaudeCommand(_ command: String, profile: Int) {
        // Check permission and update UI if needed
        if !hasAccessibilityPermission() {
            NotificationCenter.default.post(name: Notification.Name("AccessibilityPermissionMissing"), object: nil)
        }
        
        print("🎮 Sending Claude command: \(command)")
        
        // Send 11 backspaces to clear any existing input before typing new command
        for _ in 0..<11 {
            simulateKeyPress(keyCode: 51) // Backspace
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        // Small delay before typing new command
        Thread.sleep(forTimeInterval: 0.05)
        
        // Always try to send the command regardless of permission check
        typeString(command)
        
        // Press Enter to execute
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.simulateKeyPress(keyCode: 36)
        }
    }
    
    func sendTextString(_ text: String) {
        // Check permission and update UI if needed
        if !hasAccessibilityPermission() {
            NotificationCenter.default.post(name: Notification.Name("AccessibilityPermissionMissing"), object: nil)
        }
        
        print("🎤 Sending transcribed text: \(text)")
        
        // Send the text without pressing Enter (let user decide when to submit)
        typeString(text)
    }
    
    func sendBackspace() {
        // Send a single backspace keypress
        simulateKeyPress(keyCode: 51) // Backspace
    }
    
    private func simulateKeyPress(keyCode: CGKeyCode) {
        NSLog("🎹 KEYMAPPER: Attempting to simulate keyCode: \(keyCode)")
        
        // Check if we have accessibility permission first
        guard AXIsProcessTrusted() else {
            NSLog("❌ KEYMAPPER: No accessibility permission - cannot send events")
            NotificationCenter.default.post(name: Notification.Name("AccessibilityPermissionMissing"), object: nil)
            return
        }
        
        // Get the frontmost application
        let frontApp = NSWorkspace.shared.frontmostApplication
        NSLog("🎯 KEYMAPPER: Frontmost app: \(frontApp?.localizedName ?? "Unknown")")
        
        // Create events with system-level event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            NSLog("❌ KEYMAPPER: Failed to create event source")
            return
        }
        
        guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else {
            NSLog("❌ KEYMAPPER: Failed to create key events")
            return
        }
        
        NSLog("✅ KEYMAPPER: Created key events successfully")
        
        // Post events to the system
        keyDown.post(tap: .cghidEventTap)
        usleep(2000) // 2ms delay between key down and up
        keyUp.post(tap: .cghidEventTap)
        
        NSLog("📤 KEYMAPPER: Posted key events to system")
    }
    
    private func simulateKeyCombo(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        NSLog("🎹 KEYMAPPER: Attempting to simulate key combo: keyCode \(keyCode), modifiers \(modifiers)")
        
        guard AXIsProcessTrusted() else {
            NSLog("❌ KEYMAPPER: No accessibility permission for key combo")
            return
        }
        
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            NSLog("❌ KEYMAPPER: Failed to create event source for combo")
            return
        }
        
        guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else {
            NSLog("❌ KEYMAPPER: Failed to create key combo events")
            return
        }
        
        keyDown.flags = modifiers
        keyUp.flags = modifiers
        
        NSLog("✅ KEYMAPPER: Created key combo events successfully")
        keyDown.post(tap: .cghidEventTap)
        usleep(2000) // 2ms delay
        keyUp.post(tap: .cghidEventTap)
        NSLog("📤 KEYMAPPER: Posted key combo events")
    }
    
    private func typeString(_ string: String) {
        // Use direct Unicode typing for better character support
        print("🎤 DEBUG: About to type string: '\(string)'")
        typeStringDirectly(string)
    }
    
    private func typeStringDirectly(_ string: String) {
        guard AXIsProcessTrusted() else { return }
        
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else { return }
        
        // Create a keyboard event for typing the entire string
        if let event = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true) {
            let utf16Array = Array(string.utf16)
            utf16Array.withUnsafeBufferPointer { buffer in
                if let baseAddress = buffer.baseAddress {
                    event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: baseAddress)
                }
            }
            event.post(tap: .cghidEventTap)
            print("🎤 DEBUG: Posted Unicode string event for: '\(string)'")
        }
    }
    
    private func keyCodeForCharacter(_ char: Character) -> CGKeyCode? {
        let characterMap: [Character: CGKeyCode] = [
            // Letters
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 23,
            "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "]": 30, "o": 31,
            "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38, "'": 39,
            "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46,
            ".": 47, "`": 50,
            
            // Special characters  
            " ": 49, // Space
            "\n": 36, // Return/Enter
            "\t": 48, // Tab
        ]
        
        return characterMap[Character(char.lowercased())]
    }
    
    private func simulateMouseScroll(deltaX: Double, deltaY: Double) {
        NSLog("🖱️ KEYMAPPER: Simulating mouse scroll - deltaX: \(deltaX), deltaY: \(deltaY)")
        
        guard AXIsProcessTrusted() else {
            NSLog("❌ KEYMAPPER: No accessibility permission for mouse scroll")
            return
        }
        
        // Create scroll event
        guard let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, 
                                      units: .pixel, 
                                      wheelCount: 2, 
                                      wheel1: Int32(deltaY), 
                                      wheel2: Int32(deltaX), 
                                      wheel3: 0) else {
            NSLog("❌ KEYMAPPER: Failed to create scroll event")
            return
        }
        
        // Post the scroll event
        scrollEvent.post(tap: .cghidEventTap)
        NSLog("📤 KEYMAPPER: Posted scroll event")
    }
}