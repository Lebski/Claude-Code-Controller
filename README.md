# ClaudeController 🎮

Transform your PS5 DualSense controller into a powerful navigation and command tool for Claude Code. Navigate, execute commands, and switch between profiles with gamepad precision.

![ClaudeController Logo](ClaudeCodev2/Assets.xcassets/logo.imageset/logo.png)

## ✨ Features

- **🎯 Precise Navigation**: Use D-Pad for arrow key navigation in Claude Code
- **⚡ Quick Commands**: Execute Claude commands instantly with button combos
- **🎨 Profile System**: 3 switchable profiles with color-coded feedback via DualSense light bar
- **🎙️ Voice Input**: Speech-to-text integration for natural language commands
- **📊 Real-time Feedback**: Visual button state indicators and connection status
- **🔧 Custom Commands**: Install and manage custom Claude command shortcuts

## 🚀 Installation

### Prerequisites
- macOS 12.0 or later
- Xcode 14.0+ (for building from source)
- PS5 DualSense Controller
- Bluetooth enabled on your Mac

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ClaudeController.git
cd ClaudeController/ClaudeCodev2
```

2. Open in Xcode:
```bash
open ClaudeCodev2.xcodeproj
```

3. Build and run:
   - Press `Cmd+B` to build
   - Press `Cmd+R` to run

### First-Time Setup

1. **Grant Permissions**:
   - Bluetooth access (for controller connection)
   - Accessibility permission (System Preferences → Security & Privacy → Privacy → Accessibility)
   - Microphone access (for speech input, optional)

2. **Connect Your Controller**:
   - Open System Preferences → Bluetooth
   - Put DualSense in pairing mode (hold PS + Share buttons)
   - Click "Connect" when the controller appears

3. **Install Custom Commands**:
   - Launch ClaudeController
   - Navigate to the Configuration tab
   - Click "Install Custom Claude Commands"

## 🎮 Controller Mappings

### Universal Controls (All Profiles)

| Button | Action |
|--------|--------|
| **D-Pad** | Arrow keys navigation |
| **Circle (○)** | Enter/Accept |
| **Cross (✕)** | Escape/Cancel |
| **Triangle (△)** | Auto-accept (Cmd+Enter) |
| **Square (□)** | Type `/` for commands |
| **Left Stick** | Mouse movement (when implemented) |
| **Right Stick** | Scroll navigation |
| **PS Button** | Show/Hide app |

### Profile-Specific Commands

| Profile | Color | L1 | R1 | R2 |
|---------|-------|----|----|-----|
| **Profile 1** | 🔵 Blue | `/init` | `/review` | `/test` |
| **Profile 2** | 🟢 Green | `/init` | `/review` | `/securitycheck` |
| **Profile 3** | 🔴 Red | `/init` | `/review` | `/documentation` |

### Special Functions

| Control | Action |
|---------|--------|
| **L2 (Hold)** | Switch profiles (cycles through 1→2→3→1) |
| **Options** | Settings/Configuration |
| **Share** | Screenshot (when implemented) |
| **Touchpad Press** | Toggle voice input |

## 📱 App Interface

The app features a clean SwiftUI interface with two main tabs:

### Controller Tab
- Real-time button state visualization
- Current profile indicator with color coding
- Active profile's command mappings
- Connection status with helpful instructions

### Status Tab
- Detailed connection information
- Step-by-step setup guide
- Troubleshooting tips
- Custom command installation

## 🔧 Configuration

### Custom Commands

The app can install helpful Claude commands to your shell configuration:

- **`init`**: Initialize Claude in the current directory
- **`review`**: Request a code review
- **`test`**: Run tests
- **`securitycheck`**: Perform security analysis
- **`documentation`**: Generate documentation

These commands are automatically added to your shell profile (`~/.zshrc` or `~/.bash_profile`).

### Profile Customization

Each profile can be customized for different workflows:
- **Profile 1 (Blue)**: General development
- **Profile 2 (Green)**: Security-focused development
- **Profile 3 (Red)**: Documentation and review

## 🏗️ Architecture

Built with modern Swift and SwiftUI:

- **SwiftUI**: Native macOS app with reactive UI
- **GameController Framework**: DualSense integration
- **CoreGraphics**: Keyboard event simulation
- **Speech Framework**: Voice-to-text conversion
- **Combine**: Reactive state management

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for enhancing the Claude Code experience
- Inspired by the need for more intuitive code navigation
- Thanks to the Swift and GameController framework communities

## 🐛 Troubleshooting

### Controller Not Connecting
1. Ensure Bluetooth is enabled
2. Reset controller (small button on back)
3. Remove and re-pair in Bluetooth settings

### Commands Not Working
1. Grant Accessibility permission in System Preferences
2. Ensure Claude Code is the active application
3. Check that custom commands are installed

### No Response from Buttons
1. Check the app's status tab for connection info
2. Verify controller battery level
3. Try reconnecting the controller

## 📧 Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

Made with ❤️ for the Claude Code community