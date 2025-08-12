import SwiftUI

struct ConfigurationView: View {
    @ObservedObject var controllerManager: ControllerManager
    @State private var installStatus = "Ready to install commands"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Controller Settings")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Status: \(controllerManager.statusMessage)")
                    .foregroundColor(controllerManager.isConnected ? .green : .orange)
                    .font(.headline)
            }
            
            Divider()
            
            // Button States Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Controller Button States")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ButtonStateRow(name: "D-Pad Up → Up Arrow", id: "dpad_up", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "D-Pad Down → Down Arrow", id: "dpad_down", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "D-Pad Left → Delete/Back", id: "dpad_left", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "D-Pad Right → Enter/In", id: "dpad_right", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "Circle (○) → Accept/Enter", id: "circle", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "Cross (✕) → Cancel/Escape", id: "cross", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "Triangle (△) → Auto Accept", id: "triangle", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "Square (□) → Speech-to-Text", id: "square", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "L1 → /documentation", id: "l1", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "R1 → /review", id: "r1", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "L2 → [Not Mapped]", id: "l2", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "R2 → /securitycheck", id: "r2", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "Options → [Not Available]", id: "options", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "Left Stick → Mouse Scroll", id: "left_stick", states: controllerManager.buttonStates)
                    ButtonStateRow(name: "Right Stick → [Not Mapped]", id: "right_stick", states: controllerManager.buttonStates)
                }
            }
            
            Divider()
            
            // Command Installation Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Install Custom Claude Commands")
                    .font(.headline)
                
                Text("Install additional commands for enhanced functionality")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Button("Install /securitycheck") {
                        installCommand(name: "securitycheck", script: getSecurityCheckScript())
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Install /documentation") {
                        installCommand(name: "documentation", script: getDocumentationScript())
                    }
                    .buttonStyle(.borderedProminent)
                }
            
                
                Text("Status: \(installStatus)")
                    .font(.caption)
                    .foregroundColor(installStatus.contains("🟢") ? .green : installStatus.contains("🔴") ? .red : .secondary)
            }
            
            Divider()
            
            // Debug & Troubleshooting Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug & Troubleshooting")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    Button("Test Accessibility Permission") {
                        testAccessibilityPermission()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Recheck Permissions") {
                        controllerManager.startMonitoring()
                    }
                    .buttonStyle(.bordered)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("If permissions aren't working:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("1. Go to System Preferences > Security & Privacy > Privacy > Accessibility")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("2. Remove ClaudeCodev2 if present, then re-add it")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("3. Restart the app after granting permission")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func installCommand(name: String, script: String) {
        let commandsDir = "\(NSHomeDirectory())/.config/claude/commands"
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(atPath: commandsDir, withIntermediateDirectories: true, attributes: nil)
            let scriptPath = "\(commandsDir)/\(name)"
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            // Make executable
            let task = Process()
            task.launchPath = "/bin/chmod"
            task.arguments = ["+x", scriptPath]
            try task.run()
            task.waitUntilExit()
            
            installStatus = "🟢 Successfully installed /\(name)"
        } catch {
            installStatus = "🔴 Failed to install /\(name): \(error.localizedDescription)"
        }
    }
    
    private func testAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        print("🧪 Manual accessibility test: \(trusted)")
        installStatus = "🧪 Accessibility test: \(trusted ? "🟢 Granted" : "🔴 Not granted")"
        
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            let result = AXIsProcessTrustedWithOptions(options)
            print("🧪 Manual permission prompt result: \(result)")
        }
    }
    
}

struct ButtonStateRow: View {
    let name: String
    let id: String
    let states: [String: Bool]
    
    var body: some View {
        HStack {
            Circle()
                .fill(isPressed ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)
            
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isPressed ? .green : .primary)
                .fontWeight(isPressed ? .bold : .regular)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private var isPressed: Bool {
        states[id] ?? false
    }
}

// MARK: - Command Scripts

private func getSecurityCheckScript() -> String {
    return """
#!/bin/bash
# Advanced Security Check Command for Claude Code
# Performs comprehensive security analysis of code repositories

echo "🔒 Running Advanced Security Check..."
echo "=================================="

# Check for common security vulnerabilities
echo "🔍 Scanning for security vulnerabilities..."

# Look for hardcoded credentials
echo "📋 Checking for hardcoded credentials:"
grep -r -i "password\\|api_key\\|secret\\|token" --include="*.swift" --include="*.js" --include="*.py" --include="*.java" . 2>/dev/null | head -5

# Check for SQL injection patterns
echo ""
echo "📋 Checking for potential SQL injection vulnerabilities:"
grep -r "SELECT\\|INSERT\\|UPDATE\\|DELETE" --include="*.swift" --include="*.js" --include="*.py" --include="*.java" . 2>/dev/null | grep -v "//\\|#\\|--" | head -3

# Check for XSS vulnerabilities
echo ""
echo "📋 Checking for potential XSS vulnerabilities:"
grep -r "innerHTML\\|document.write\\|eval(" --include="*.js" --include="*.html" . 2>/dev/null | head -3

# Check file permissions
echo ""
echo "📋 Checking sensitive file permissions:"
find . -name "*.pem" -o -name "*.key" -o -name "*.p12" 2>/dev/null | xargs ls -la 2>/dev/null

echo ""
echo "✅ Security check complete!"
echo "💡 Review any flagged items above for potential security issues"
"""
}

private func getDocumentationScript() -> String {
    return """
#!/bin/bash
# Advanced Documentation Generator for Claude Code
# Analyzes code structure and generates comprehensive documentation

echo "📚 Running Documentation Analysis..."
echo "==================================="

# Count code files by type
echo "📊 Code Structure Analysis:"
echo "Swift files: $(find . -name "*.swift" 2>/dev/null | wc -l | xargs)"
echo "JavaScript files: $(find . -name "*.js" 2>/dev/null | wc -l | xargs)"
echo "Python files: $(find . -name "*.py" 2>/dev/null | wc -l | xargs)"
echo "Markdown files: $(find . -name "*.md" 2>/dev/null | wc -l | xargs)"

# Analyze project structure
echo ""
echo "📁 Project Structure:"
find . -type d -name "Sources" -o -name "src" -o -name "lib" -o -name "components" 2>/dev/null | head -5

# Look for existing documentation
echo ""
echo "📖 Existing Documentation:"
find . -name "README*" -o -name "DOCS*" -o -name "*.md" 2>/dev/null | head -5

# Find public functions/classes that might need documentation
echo ""
echo "🔍 Public APIs that may need documentation:"
grep -r "public func\\|public class\\|export function\\|def " --include="*.swift" --include="*.js" --include="*.py" . 2>/dev/null | head -5

# Check for TODO comments
echo ""
echo "📝 TODO items found:"
grep -r "TODO\\|FIXME\\|HACK" --include="*.swift" --include="*.js" --include="*.py" . 2>/dev/null | head -3

echo ""
echo "✅ Documentation analysis complete!"
echo "💡 Consider adding documentation for the public APIs listed above"
"""
}

#Preview {
    ConfigurationView(controllerManager: ControllerManager())
}
