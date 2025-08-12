import Cocoa
import GameController
import SwiftUI
import Speech

class ControllerManager: NSObject, ObservableObject {
    
    @Published var isConnected = false
    @Published var statusMessage = "Waiting for controller connection..."
    @Published var buttonStates: [String: Bool] = [:]
    
    private var controller: GCController?
    private let keyMapper = KeyMapper()
    private var r2Pressed = false
    
    // Speech recognition
    @Published var speechRecognizer = SpeechRecognizer()
    @Published var isRecordingEnabled = false
    
    override init() {
        super.init()
        setupControllerNotifications()
        setupAccessibilityNotifications()
    }
    
    func startMonitoring() {
        // Check accessibility permissions once on startup
        if !keyMapper.checkAccessibilityPermissionOnStartup() {
            updateStatus("⚠️ Accessibility permission required - please grant in System Preferences")
        } else {
            updateStatus("🟢 Accessibility permission granted")
        }
        
        // Initialize speech recognition
        speechRecognizer.requestPermissions()
        isRecordingEnabled = true
        
        // Initialize microphone selection at startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.initializeMicrophone()
        }
        
        // Enable controller discovery for all apps, not just when focused
        GCController.shouldMonitorBackgroundEvents = true
        GCController.startWirelessControllerDiscovery()
        checkForControllers()
        
        print("🎮 CONTROLLER: Background monitoring enabled: \(GCController.shouldMonitorBackgroundEvents)")
    }
    
    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }
    
    private func setupAccessibilityNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityPermissionMissing),
            name: Notification.Name("AccessibilityPermissionMissing"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityPermissionGranted),
            name: Notification.Name("AccessibilityPermissionGranted"),
            object: nil
        )
    }
    
    @objc private func accessibilityPermissionMissing() {
        updateStatus("🔴 Accessibility permission required - buttons won't work until granted")
    }
    
    @objc private func accessibilityPermissionGranted() {
        updateStatus("🟢 Accessibility permission granted - controller ready!")
    }
    
    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        
        if controller.productCategory == "DualSense" || controller.vendorName == "Sony" {
            self.controller = controller
            setupControllerInput(controller)
            updateStatus("DualSense Connected")
            isConnected = true
            print("DualSense controller connected")
        }
    }
    
    @objc private func controllerDidDisconnect(_ notification: Notification) {
        updateStatus("Controller Disconnected")
        controller = nil
        isConnected = false
        print("Controller disconnected")
    }
    
    private func checkForControllers() {
        for controller in GCController.controllers() {
            if controller.productCategory == "DualSense" || controller.vendorName == "Sony" {
                self.controller = controller
                setupControllerInput(controller)
                updateStatus("DualSense Connected")
                isConnected = true
                break
            }
        }
    }
    
    private func setupControllerInput(_ controller: GCController) {
        guard let extended = controller.extendedGamepad else { return }
        
        // D-Pad navigation
        extended.dpad.valueChangedHandler = { [weak self] (dpad, xValue, yValue) in
            if yValue > 0.5 {
                self?.keyMapper.sendKeyPress(.upArrow)
                self?.updateButtonState("dpad_up", pressed: true)
            } else if yValue < -0.5 {
                self?.keyMapper.sendKeyPress(.downArrow)
                self?.updateButtonState("dpad_down", pressed: true)
            } else {
                self?.updateButtonState("dpad_up", pressed: false)
                self?.updateButtonState("dpad_down", pressed: false)
            }
            
            if xValue > 0.5 {
                self?.keyMapper.sendKeyPress(.rightArrow)
                self?.updateButtonState("dpad_right", pressed: true)
            } else if xValue < -0.5 {
                self?.keyMapper.sendKeyPress(.leftArrow)
                self?.updateButtonState("dpad_left", pressed: true)
            } else {
                self?.updateButtonState("dpad_right", pressed: false)
                self?.updateButtonState("dpad_left", pressed: false)
            }
        }
        
        // Face buttons
        extended.buttonA.pressedChangedHandler = { [weak self] (button, value, pressed) in
            NSLog("🎮 CONTROLLER: X/Cross button pressed: \(pressed) - Background events: \(GCController.shouldMonitorBackgroundEvents)")
            self?.updateButtonState("cross", pressed: pressed)
            if pressed {
                NSLog("🎮 CONTROLLER: Sending X key for X button")
                self?.keyMapper.sendKeyPress(.x)
            }
        }
        
        extended.buttonB.pressedChangedHandler = { [weak self] (button, value, pressed) in
            self?.updateButtonState("circle", pressed: pressed)
            if pressed {
                self?.keyMapper.sendKeyPress(.enter)
            }
        }
        
        extended.buttonY.pressedChangedHandler = { [weak self] (button, value, pressed) in
            self?.updateButtonState("triangle", pressed: pressed)
            if pressed {
                self?.keyMapper.sendKeyPress(.autoAccept)
            }
        }
        
        extended.buttonX.pressedChangedHandler = { [weak self] (button, value, pressed) in
            self?.updateButtonState("square", pressed: pressed)
            
            // Handle speech recognition on square button press
            if pressed && (self?.isRecordingEnabled ?? false) {
                if self?.speechRecognizer.isRecording == true {
                    // If currently recording, stop recording (text will be sent automatically)
                    print("🎤 SPEECH: Square button pressed - stopping recording")
                    self?.speechRecognizer.stopRecording()
                } else {
                    // If not recording, start recording
                    print("🎤 SPEECH: Square button pressed - starting speech recognition")
                    self?.speechRecognizer.startRecording()
                }
            }
        }
        
        // Shoulder buttons
        extended.leftShoulder.pressedChangedHandler = { [weak self] (button, value, pressed) in
            self?.updateButtonState("l1", pressed: pressed)
            if pressed {
                self?.keyMapper.sendClaudeCommand("/documentation", profile: 0)
            }
        }
        
        extended.rightShoulder.pressedChangedHandler = { [weak self] (button, value, pressed) in
            self?.updateButtonState("r1", pressed: pressed)
            if pressed {
                self?.keyMapper.sendClaudeCommand("/review", profile: 0)
            }
        }
        
        // L2 trigger
        extended.leftTrigger.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.updateButtonState("l2", pressed: value > 0.1)
        }
        
        // R2 for security check
        extended.rightTrigger.valueChangedHandler = { [weak self] (button, value, pressed) in
            let isPressed = value > 0.8
            self?.updateButtonState("r2", pressed: value > 0.1)
            
            if isPressed && !(self?.r2Pressed ?? false) {
                self?.r2Pressed = true
                self?.keyMapper.sendClaudeCommand("/securitycheck", profile: 0)
            } else if !isPressed {
                self?.r2Pressed = false
            }
        }
        
        // Additional buttons
        // Note: Options button is not available through GameController framework on DualSense
        // Speech recognition has been moved to Square button instead
        
        extended.buttonMenu.pressedChangedHandler = { [weak self] (button, value, pressed) in
            self?.updateButtonState("menu", pressed: pressed)
        }
        
        extended.buttonHome?.pressedChangedHandler = { [weak self] (button, value, pressed) in
            self?.updateButtonState("home", pressed: pressed)
        }
        
        // Thumbsticks
        extended.leftThumbstick.valueChangedHandler = { [weak self] (dpad, xValue, yValue) in
            let isPressed = abs(xValue) > 0.1 || abs(yValue) > 0.1
            self?.updateButtonState("left_stick", pressed: isPressed)
            
            // Handle scroll when stick is moved
            if isPressed {
                // Scale the values for smooth scrolling
                let scrollSensitivity = 15.0
                let deltaX = Double(xValue) * scrollSensitivity
                let deltaY = Double(yValue) * scrollSensitivity
                
                self?.keyMapper.sendKeyPress(.scroll(deltaX: deltaX, deltaY: deltaY))
            }
        }
        
        extended.rightThumbstick.valueChangedHandler = { [weak self] (dpad, xValue, yValue) in
            let isPressed = abs(xValue) > 0.5 || abs(yValue) > 0.5
            self?.updateButtonState("right_stick", pressed: isPressed)
        }
    }
    
    
    private func updateStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = status
            print("Status: \(status)")
            
            // Update status bar icon if available - will be defined in App file
            // This will be handled via notification or direct access
        }
    }
    
    private func updateButtonState(_ buttonId: String, pressed: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.buttonStates[buttonId] = pressed
        }
    }
    
    private func initializeMicrophone() {
        // Initialize microphone at startup
        speechRecognizer.initializeMicrophoneAtStartup()
    }
    
}