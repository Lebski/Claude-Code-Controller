import Foundation
import Speech
import AVFoundation
import SwiftUI
import AudioToolbox
import CoreAudio

class SpeechRecognizer: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcription = ""
    @Published var speechStatus = "Ready for speech recognition"
    @Published var useCloudRecognition = true // Default to cloud to avoid local service issues
    @Published var hasTranscriptionReady = false // New: Track if we have text ready to send
    
    private var lastSentTranscription = ""
    private var transcriptionTimer: Timer?
    private var lastSentLength = 0
    
    // Microphone selection
    var selectedMicrophoneID: String? {
        didSet {
            print("🎤 Selected microphone changed to: \(selectedMicrophoneID ?? "default")")
        }
    }
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        requestPermissions()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
        updateSpeechStatus("Speech recognizer initialized")
    }
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.updateSpeechStatus("🟢 Speech recognition authorized")
                case .denied:
                    self?.updateSpeechStatus("🔴 Speech recognition denied")
                case .restricted:
                    self?.updateSpeechStatus("🔴 Speech recognition restricted")
                case .notDetermined:
                    self?.updateSpeechStatus("⚠️ Speech recognition not determined")
                @unknown default:
                    self?.updateSpeechStatus("🔴 Unknown speech recognition status")
                }
            }
        }
    }
    
    func startRecording() {
        // Stop any existing recording first
        if isRecording {
            stopRecording()
            return
        }
        
        // Check permissions and availability
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            updateSpeechStatus("🔴 Speech recognizer not available")
            return
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            updateSpeechStatus("🔴 Speech recognition not authorized")
            return
        }
        
        // Start recording
        do {
            // Cancel any existing task
            recognitionTask?.cancel()
            recognitionTask = nil
            
            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                updateSpeechStatus("🔴 Failed to create recognition request")
                return
            }
            
            // Configure request - force cloud recognition for now
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false // Always use cloud
            
            // Stop audio engine if running
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            
            let inputNode = audioEngine.inputNode
            
            // Configure audio input with selected microphone BEFORE starting the engine
            try configureAudioInput(inputNode: inputNode)
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Install tap
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            // Start audio engine with small delay for device configuration
            audioEngine.prepare()
            
            // Small delay to ensure audio unit configuration is applied
            usleep(50000) // 50ms delay
            
            try audioEngine.start()
            
            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        let newTranscription = result.bestTranscription.formattedString
                        self?.transcription = newTranscription
                        
                        // Send new words immediately as they're recognized
                        self?.handleNewTranscription(newTranscription)
                        
                        if result.isFinal {
                            self?.handleFinalTranscription(newTranscription)
                            self?.stopRecording()
                        }
                    }
                    
                    if let error = error {
                        let nsError = error as NSError
                        // Ignore cancellation errors (code 301) - they're expected when we stop manually
                        if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                            print("🎤 Recognition was cancelled (expected)")
                            // Send whatever we have transcribed so far
                            if let finalText = self?.transcription, !finalText.isEmpty {
                                self?.handleFinalTranscription(finalText)
                            }
                        } else {
                            print("🎤 Recognition error: \(error)")
                            self?.updateSpeechStatus("🔴 Recognition failed")
                        }
                        self?.stopRecording()
                    }
                }
            }
            
            // Update state - simple recording without any text sending
            isRecording = true
            transcription = ""
            lastSentTranscription = ""
            lastSentLength = 0
            transcriptionTimer?.invalidate()
            updateSpeechStatus("🎤 Recording... Speak now!")
            
        } catch {
            updateSpeechStatus("🔴 Failed to start: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Send current transcription before stopping
        if !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("🎤 DEBUG: Manual stop - sending transcription: '\(transcription)'")
            handleFinalTranscription(transcription)
        } else {
            updateSpeechStatus("🔴 No speech detected")
        }
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Clean up recognition
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Clean up timers
        transcriptionTimer?.invalidate()
        transcriptionTimer = nil
        
        isRecording = false
        updateSpeechStatus("🟢 Recording stopped")
    }
    
    private func configureAudioInput(inputNode: AVAudioInputNode) throws {
        guard let selectedMicrophoneID = selectedMicrophoneID else {
            print("🎤 Using default microphone")
            return
        }
        
        print("🎤 Setting audio input device to: \(selectedMicrophoneID)")
        
        // Get the audio unit from the input node
        let audioUnit = inputNode.audioUnit!
        
        // Configure audio unit for selected device
        
        // Convert device ID to AudioDeviceID (UInt32)
        var deviceID: AudioDeviceID = 0
        
        // Find the audio device by UID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        
        if status == noErr {
            let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
            let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
            defer { devices.deallocate() }
            
            status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, devices)
            
            if status == noErr {
                // Search through all devices to find the one with matching UID
                for i in 0..<deviceCount {
                    let device = devices[i]
                    
                    // Get device UID
                    address.mSelector = kAudioDevicePropertyDeviceUID
                    var uidSize: UInt32 = 0
                    status = AudioObjectGetPropertyDataSize(device, &address, 0, nil, &uidSize)
                    
                    if status == noErr {
                        let uidPtr = UnsafeMutablePointer<CFString>.allocate(capacity: 1)
                        defer { uidPtr.deallocate() }
                        
                        status = AudioObjectGetPropertyData(device, &address, 0, nil, &uidSize, uidPtr)
                        
                        if status == noErr {
                            let deviceUID = uidPtr.pointee as String
                            if deviceUID == selectedMicrophoneID {
                                deviceID = device
                                print("✅ Found matching device: \(deviceUID) -> ID: \(deviceID)")
                                break
                            }
                        }
                    }
                }
            }
        }
        
        if deviceID != 0 {
            // Set the current device property on the audio unit
            status = AudioUnitSetProperty(audioUnit,
                                        kAudioOutputUnitProperty_CurrentDevice,
                                        kAudioUnitScope_Global,
                                        0,
                                        &deviceID,
                                        UInt32(MemoryLayout<AudioDeviceID>.size))
            
            if status == noErr {
                print("✅ Audio input device configured")
            } else {
                print("❌ Failed to set audio input device: \(status)")
            }
        } else {
            print("❌ Could not find audio device with UID: \(selectedMicrophoneID)")
        }
    }
    
    private func handleNewTranscription(_ newText: String) {
        // Only update if text actually changed and has meaningful content
        guard newText != lastSentTranscription && !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        print("🎤 Transcribing: '\(newText)'")
        
        // During recording, just update the internal state - don't send any text
        // Update tracking variables for UI display only
        lastSentTranscription = newText
        updateSpeechStatus("🎤 Recording: \(newText)")
    }
    
    private func handleFinalTranscription(_ finalText: String) {
        // When recording stops, simply send the transcribed text
        if !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("🎤 DEBUG: Sending final transcription: '\(finalText)'")
            let keyMapper = KeyMapper()
            keyMapper.sendTextString(finalText)
            
            updateSpeechStatus("🟢 Sent: \(finalText)")
        } else {
            updateSpeechStatus("🔴 No speech detected")
        }
        
        // Clear after a longer delay since we're waiting for button press
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.transcription = ""
            self.lastSentTranscription = ""
            self.lastSentLength = 0
            self.hasTranscriptionReady = false
            self.updateSpeechStatus("Ready for speech recognition")
        }
    }
    
    func sendHeldTranscription() {
        guard hasTranscriptionReady, !transcription.isEmpty else {
            print("🎤 No transcription ready to send")
            return
        }
        
        print("🎤 DEBUG: About to send transcription: '\(transcription)'")
        let keyMapper = KeyMapper()
        keyMapper.sendTextString(transcription)
        
        updateSpeechStatus("🟢 Sent: \(transcription)")
        
        // Clear everything after sending
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.transcription = ""
            self.lastSentTranscription = ""
            self.lastSentLength = 0
            self.hasTranscriptionReady = false
            self.updateSpeechStatus("Ready for speech recognition")
        }
    }
    
    private func updateSpeechStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.speechStatus = status
            print("🎤 \(status)")
        }
    }
    
    func initializeMicrophoneAtStartup() {
        print("🎤 Initializing microphone at app startup")
        updateSpeechStatus("🎤 Initializing microphone...")
        
        // Load available microphones and auto-select the best one
        DispatchQueue.main.async {
            self.loadAndSelectBestMicrophone()
        }
    }
    
    private func loadAndSelectBestMicrophone() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        
        guard status == noErr else {
            print("❌ Failed to get audio devices at startup")
            updateSpeechStatus("❌ Failed to initialize microphone")
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
        defer { devices.deallocate() }
        
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, devices)
        
        guard status == noErr else {
            print("❌ Failed to get audio device data at startup")
            updateSpeechStatus("❌ Failed to initialize microphone")
            return
        }
        
        var availableMics: [(id: String, name: String)] = []
        
        for i in 0..<deviceCount {
            let device = devices[i]
            
            // Check if this is an input device
            address.mSelector = kAudioDevicePropertyStreams
            address.mScope = kAudioDevicePropertyScopeInput
            
            var streamDataSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(device, &address, 0, nil, &streamDataSize)
            
            // If it has input streams, it's an input device
            if status == noErr && streamDataSize > 0 {
                // Get device UID
                address.mSelector = kAudioDevicePropertyDeviceUID
                address.mScope = kAudioObjectPropertyScopeGlobal
                var uidSize: UInt32 = 0
                status = AudioObjectGetPropertyDataSize(device, &address, 0, nil, &uidSize)
                
                if status == noErr {
                    let uidPtr = UnsafeMutablePointer<CFString>.allocate(capacity: 1)
                    defer { uidPtr.deallocate() }
                    
                    status = AudioObjectGetPropertyData(device, &address, 0, nil, &uidSize, uidPtr)
                    
                    if status == noErr {
                        let deviceUID = uidPtr.pointee as String
                        
                        // Get device name
                        address.mSelector = kAudioDevicePropertyDeviceNameCFString
                        var nameSize: UInt32 = 0
                        status = AudioObjectGetPropertyDataSize(device, &address, 0, nil, &nameSize)
                        
                        if status == noErr {
                            let namePtr = UnsafeMutablePointer<CFString>.allocate(capacity: 1)
                            defer { namePtr.deallocate() }
                            
                            status = AudioObjectGetPropertyData(device, &address, 0, nil, &nameSize, namePtr)
                            
                            if status == noErr {
                                let deviceName = namePtr.pointee as String
                                availableMics.append((id: deviceUID, name: deviceName))
                                print("🎤 Found input device: \(deviceName) (\(deviceUID))")
                            }
                        }
                    }
                }
            }
        }
        
        // Auto-select the best microphone - prioritize external mics
        if !availableMics.isEmpty {
            let preferredMic = availableMics.first { $0.name.contains("RODE") } ??
                              availableMics.first { !$0.name.contains("Built-in") } ??
                              availableMics.first
            
            if let mic = preferredMic {
                selectedMicrophoneID = mic.id
                print("🎤 Auto-selected microphone: \(mic.name)")
                updateSpeechStatus("🟢 Microphone ready: \(mic.name)")
            }
        } else {
            print("🎤 No input devices found, using system default")
            updateSpeechStatus("🟢 Microphone ready (system default)")
        }
    }
    
    // Removed complex audio device initialization - will happen in SpeechView
    
    private func listAvailableInputDevices() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        
        guard status == noErr else {
            print("🎤 DEBUG: Failed to get audio devices")
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
        defer { devices.deallocate() }
        
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, devices)
        
        guard status == noErr else {
            print("🎤 DEBUG: Failed to get audio device data")
            return
        }
        
        print("🎤 DEBUG: Available input devices:")
        
        for i in 0..<deviceCount {
            let device = devices[i]
            
            // Check if this is an input device
            address.mSelector = kAudioDevicePropertyStreams
            address.mScope = kAudioDevicePropertyScopeInput
            
            var streamDataSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(device, &address, 0, nil, &streamDataSize)
            
            if status == noErr && streamDataSize > 0 {
                // Get device UID and name
                address.mSelector = kAudioDevicePropertyDeviceUID
                address.mScope = kAudioObjectPropertyScopeGlobal
                var uidSize: UInt32 = 0
                status = AudioObjectGetPropertyDataSize(device, &address, 0, nil, &uidSize)
                
                if status == noErr {
                    let uidPtr = UnsafeMutablePointer<CFString>.allocate(capacity: 1)
                    defer { uidPtr.deallocate() }
                    
                    status = AudioObjectGetPropertyData(device, &address, 0, nil, &uidSize, uidPtr)
                    
                    if status == noErr {
                        let deviceUID = uidPtr.pointee as String
                        
                        // Get device name
                        address.mSelector = kAudioDevicePropertyDeviceNameCFString
                        var nameSize: UInt32 = 0
                        status = AudioObjectGetPropertyDataSize(device, &address, 0, nil, &nameSize)
                        
                        if status == noErr {
                            let namePtr = UnsafeMutablePointer<CFString>.allocate(capacity: 1)
                            defer { namePtr.deallocate() }
                            
                            status = AudioObjectGetPropertyData(device, &address, 0, nil, &nameSize, namePtr)
                            
                            if status == noErr {
                                let deviceName = namePtr.pointee as String
                                print("🎤 DEBUG: - \(deviceName) (UID: \(deviceUID)) [ID: \(device)]")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognizer: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async { [weak self] in
            if available {
                self?.updateSpeechStatus("🟢 Speech recognizer available")
            } else {
                self?.updateSpeechStatus("🔴 Speech recognizer unavailable")
                self?.stopRecording()
            }
        }
    }
}
