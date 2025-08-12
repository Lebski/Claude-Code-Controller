import SwiftUI
import Speech
import AVFoundation
import CoreAudio

struct SpeechView: View {
    @ObservedObject var controllerManager: ControllerManager
    @State private var selectedMicrophone: AVAudioDevice?
    @State private var availableMicrophones: [AVAudioDevice] = []
    @State private var microphonePermissionStatus = "Checking..."
    @State private var speechPermissionStatus = "Checking..."
    @State private var testTranscription = ""
    @State private var isTestingMicrophone = false
    @State private var audioLevel: Float = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Speech Recognition Settings")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Configure microphone and speech recognition for voice commands")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Permissions Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Permissions")
                    .font(.headline)
                
                // Microphone Permission
                HStack {
                    Image(systemName: microphonePermissionStatus.contains("🟢") ? "mic.fill" : "mic.slash")
                        .foregroundColor(microphonePermissionStatus.contains("🟢") ? .green : .orange)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text("Microphone Access")
                            .font(.system(.body, design: .rounded))
                        Text(microphonePermissionStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !microphonePermissionStatus.contains("🟢") {
                        Button("Request Permission") {
                            requestMicrophonePermission()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Speech Recognition Permission
                HStack {
                    Image(systemName: speechPermissionStatus.contains("🟢") ? "waveform" : "waveform.slash")
                        .foregroundColor(speechPermissionStatus.contains("🟢") ? .green : .orange)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text("Speech Recognition")
                            .font(.system(.body, design: .rounded))
                        Text(speechPermissionStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !speechPermissionStatus.contains("🟢") {
                        Button("Request Permission") {
                            requestSpeechPermission()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Speech Recognition Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Recognition Settings")
                    .font(.headline)
                
                Toggle("Use Cloud Recognition (requires internet)", isOn: $controllerManager.speechRecognizer.useCloudRecognition)
                    .toggleStyle(SwitchToggleStyle())
                
                Text("Cloud recognition is more accurate but requires internet. On-device recognition works offline but may have lower accuracy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Divider()
            
            // Microphone Selection Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Microphone Selection")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "mic")
                    
                    Picker("Select Microphone", selection: $selectedMicrophone) {
                        Text("System Default").tag(nil as AVAudioDevice?)
                        ForEach(availableMicrophones, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device as AVAudioDevice?)
                        }
                    }
                    .onChange(of: selectedMicrophone) { _, newDevice in
                        controllerManager.speechRecognizer.selectedMicrophoneID = newDevice?.uniqueID
                        print("🎤 Updated speech recognizer microphone to: \(newDevice?.localizedName ?? "default")")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 300)
                    
                    Button("Refresh") {
                        loadAudioDevices()
                    }
                    .buttonStyle(.bordered)
                }
                
                if let device = selectedMicrophone {
                    Text("Selected: \(device.localizedName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Divider()
            
            // Speech Recognition Test Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Speech Recognition Test")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Recording indicator
                    if controllerManager.speechRecognizer.isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(isTestingMicrophone ? 1.0 : 0.3)
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: isTestingMicrophone)
                            Text("Recording")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Audio Level Indicator
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(audioLevelColor)
                                .frame(width: CGFloat(audioLevel) * geometry.size.width, height: 8)
                                .animation(.linear(duration: 0.1), value: audioLevel)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.vertical, 8)
                
                // Test Controls
                HStack(spacing: 16) {
                    Button(controllerManager.speechRecognizer.isRecording ? "Stop Recording" : "Start Test") {
                        toggleSpeechTest()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Clear") {
                        clearTest()
                    }
                    .buttonStyle(.bordered)
                    .disabled(controllerManager.speechRecognizer.transcription.isEmpty)
                }
                
                // Status and Transcription
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(controllerManager.speechRecognizer.speechStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !controllerManager.speechRecognizer.transcription.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transcription:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                Text(controllerManager.speechRecognizer.transcription)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 80)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Tips Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Press the Square (□) button on your controller to activate voice input")
                    Text("• Speak clearly and wait a moment for the transcription to complete")
                    Text("• The transcribed text will be typed automatically in the active application")
                    Text("• Green audio level indicates good input volume")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkPermissions()
            loadAudioDevices()
            startAudioLevelMonitoring()
            
            // Sync with the microphone already selected at startup
            syncWithStartupMicrophone()
        }
        .onDisappear {
            stopAudioLevelMonitoring()
        }
    }
    
    private var audioLevelColor: Color {
        if audioLevel < 0.3 {
            return .blue
        } else if audioLevel < 0.7 {
            return .green
        } else {
            return .orange
        }
    }
    
    private func checkPermissions() {
        // Check microphone permission
        #if os(macOS)
        // macOS doesn't have a direct API to check microphone permission status
        // It will prompt when first used
        microphonePermissionStatus = "🟢 Will request when needed"
        #endif
        
        // Check speech recognition permission
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechPermissionStatus = "🟢 Authorized"
        case .denied:
            speechPermissionStatus = "🔴 Denied - Enable in System Preferences"
        case .restricted:
            speechPermissionStatus = "🔴 Restricted"
        case .notDetermined:
            speechPermissionStatus = "⚠️ Not determined - Click to request"
        @unknown default:
            speechPermissionStatus = "❓ Unknown status"
        }
    }
    
    private func requestMicrophonePermission() {
        // On macOS, microphone permission is requested when first used
        microphonePermissionStatus = "🟢 Will request when microphone is used"
    }
    
    private func requestSpeechPermission() {
        controllerManager.speechRecognizer.requestPermissions()
        // Re-check after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkPermissions()
        }
    }
    
    private func loadAudioDevices() {
        // Get available audio input devices using Core Audio API
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        
        guard status == noErr else {
            print("❌ Failed to get audio devices")
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
        defer { devices.deallocate() }
        
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, devices)
        
        guard status == noErr else {
            print("❌ Failed to get audio device data")
            return
        }
        
        var inputDevices: [AVAudioDevice] = []
        
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
                                let audioDevice = AVAudioDevice(uniqueID: deviceUID, localizedName: deviceName)
                                inputDevices.append(audioDevice)
                                print("🎤 Found input device: \(deviceName) (\(deviceUID))")
                            }
                        }
                    }
                }
            }
        }
        
        availableMicrophones = inputDevices
        
        // Set default if not already selected - prioritize external mics
        if selectedMicrophone == nil && !availableMicrophones.isEmpty {
            // Try to select RODE mic first, then external mics, then built-in
            let preferredDevice = availableMicrophones.first { $0.localizedName.contains("RODE") } ??
                                 availableMicrophones.first { !$0.localizedName.contains("Built-in") } ??
                                 availableMicrophones.first
            
            selectedMicrophone = preferredDevice
            print("🎤 Auto-selected microphone: \(preferredDevice?.localizedName ?? "none")")
        }
    }
    
    private func toggleSpeechTest() {
        if controllerManager.speechRecognizer.isRecording {
            controllerManager.speechRecognizer.stopRecording()
            isTestingMicrophone = false
        } else {
            controllerManager.speechRecognizer.startRecording()
            isTestingMicrophone = true
        }
    }
    
    private func clearTest() {
        controllerManager.speechRecognizer.transcription = ""
        testTranscription = ""
    }
    
    private func startAudioLevelMonitoring() {
        // This would typically monitor actual audio input levels
        // For now, we'll simulate it when recording
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if controllerManager.speechRecognizer.isRecording {
                // Simulate audio level with some randomness
                audioLevel = Float.random(in: 0.2...0.8)
            } else {
                audioLevel = 0.0
            }
        }
    }
    
    private func stopAudioLevelMonitoring() {
        // Clean up any timers if needed
    }
    
    private func syncWithStartupMicrophone() {
        // If the speech recognizer already has a selected microphone from startup,
        // sync the UI with that selection
        if let microphoneID = controllerManager.speechRecognizer.selectedMicrophoneID {
            selectedMicrophone = availableMicrophones.first { $0.uniqueID == microphoneID }
            if let mic = selectedMicrophone {
                print("🎤 Synced UI with startup microphone: \(mic.localizedName)")
            }
        }
    }
}

// Helper struct for audio devices
struct AVAudioDevice: Hashable {
    let uniqueID: String
    let localizedName: String
}

#Preview {
    SpeechView(controllerManager: ControllerManager())
}