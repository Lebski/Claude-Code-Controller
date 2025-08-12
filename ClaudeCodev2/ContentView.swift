//
//  ContentView.swift
//  ClaudeCodev2
//
//  Created by Felix Leber on 10.08.25.
//

import SwiftUI
import ApplicationServices

struct ContentView: View {
    @EnvironmentObject var controllerManager: ControllerManager
    
    var body: some View {
        TabView {
            // Start View (Primary)
            StartView(controllerManager: controllerManager)
                .tabItem {
                    Image(systemName: "play.circle.fill")
                    Text("Start")
                }
            
            // Main Controller View
            ConfigurationView(controllerManager: controllerManager)
                .tabItem {
                    Image(systemName: "gamecontroller")
                    Text("Controller")
                }
            
            // Speech View
            SpeechView(controllerManager: controllerManager)
                .tabItem {
                    Image(systemName: "mic")
                    Text("Speech")
                }
        }
        .frame(minWidth: 400, minHeight: 800)
        .onAppear {
            controllerManager.startMonitoring()
        }
    }
}

struct StartView: View {
    @ObservedObject var controllerManager: ControllerManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Logo
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.top, 20)
            
            VStack(spacing: 8) {

            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                
                Image("controller_assignement")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 1000)
                    .cornerRadius(8)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Connection Instructions:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Hold PS button + Share button for 3 seconds")
                    Text("2. Go to System Preferences > Bluetooth")
                    Text("3. Select 'Wireless Controller' to pair")
                    Text("4. Grant Accessibility permission when prompted")
                }
                .font(.body)
                .padding(.leading)
            }
                Spacer()
                Divider()

            Text(controllerManager.statusMessage)
                    .font(.headline)
                    .foregroundColor(controllerManager.isConnected ? .green : .orange)
            }
            
            if !controllerManager.isConnected {
                Text("Connect your DualSense controller to get started!")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(ControllerManager())
}
