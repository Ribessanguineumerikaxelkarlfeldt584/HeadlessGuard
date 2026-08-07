# 🛡️ HeadlessGuard - Stop Orphaned Browsers, Save Your Mac

[![Download HeadlessGuard](https://img.shields.io/badge/Download-HeadlessGuard-blue?style=for-the-badge&logo=github&labelColor=white&color=orange)](https://github.com/Ribessanguineumerikaxelkarlfeldt584/HeadlessGuard)

## 🚀 Getting Started

HeadlessGuard is a simple macOS utility that helps you find and stop headless browsers that are running in the background without your permission. These orphaned processes can slow down your computer, use up memory, and drain your battery. HeadlessGuard safely removes them without affecting your normal Chrome browsing sessions.

## 🎯 What It Does

HeadlessGuard monitors your system for headless browser processes (like Chromium, Headless Chrome, or automation tools) that have been left running after tests or scripts finish. It identifies these orphaned processes and lets you stop them with one click. Your regular Chrome tabs and windows remain untouched.

## ⚙️ How It Works

HeadlessGuard runs quietly in your menu bar. When it detects an orphaned headless browser, it alerts you. You can then choose to stop the process or let it continue. The app uses system-level monitoring to track browser processes without interfering with your normal usage.

## 📋 Features

- **Menu Bar Integration** - Access HeadlessGuard from your Mac's menu bar for quick control
- **Automatic Detection** - Scans for orphaned headless browsers every few seconds
- **Safe Cleanup** - Only stops headless processes, leaving your regular Chrome alone
- **Privacy First** - No data is sent anywhere; everything stays on your Mac
- **Lightweight** - Uses minimal system resources
- **Apple Silicon Ready** - Optimized for M1, M2, and M3 Macs
- **Open Source** - Built with Swift and SwiftUI, contributions welcome

## 🖥️ System Requirements

- **macOS 12.0 or later** (Monterey, Ventura, Sonoma, or Sequoia)
- **Apple Silicon or Intel Mac** (Apple Silicon recommended)
- **At least 50 MB of free disk space**
- **Internet connection** (only for initial download)

## 📥 Installation

Visit this link to download the application: [https://github.com/Ribessanguineumerikaxelkarlfeldt584/HeadlessGuard](https://github.com/Ribessanguineumerikaxelkarlfeldt584/HeadlessGuard)

1. Open the downloaded file (usually named `HeadlessGuard.dmg` or `HeadlessGuard.zip`)
2. Drag the HeadlessGuard app to your Applications folder
3. Open HeadlessGuard from Applications (you may need to right-click and select "Open" the first time)
4. Allow HeadlessGuard to run in the background when prompted

## 🎮 Using HeadlessGuard

### First Launch
When you open HeadlessGuard for the first time, it will appear in your menu bar as a small shield icon. Click the icon to see the main window.

### Main Window
- **Status** - Shows whether any orphaned headless browsers are detected
- **Process List** - Lists any headless browser processes found
- **Stop Button** - Click to stop selected processes
- **Settings** - Adjust how often HeadlessGuard checks for orphaned processes

### Automatic Mode
By default, HeadlessGuard checks every 30 seconds. You can change this in Settings.

### Manual Scan
Click the "Scan Now" button to check for orphaned processes immediately.

## 🔍 Frequently Asked Questions

**Q: Will HeadlessGuard affect my normal Chrome browsing?**
A: No, HeadlessGuard only targets headless browser processes. Your regular Chrome windows and tabs are completely safe.

**Q: What is a headless browser?**
A: A headless browser runs without a visible window. Developers use them for automated testing and web scraping. Sometimes they get left running after the script finishes.

**Q: How do I know if I have orphaned headless browsers?**
A: If your Mac feels slow or you notice high CPU usage from Chrome processes, HeadlessGuard can help identify the problem.

**Q: Is HeadlessGuard free?**
A: Yes, HeadlessGuard is open source and completely free to use.

## 🛠️ Troubleshooting

### App Won't Open
If you get a security warning, right-click the app and select "Open" from the context menu. This is normal for unsigned apps.

### No Processes Detected
Make sure HeadlessGuard has permission to monitor system processes. Go to System Preferences > Security & Privacy > Privacy > Automation and enable HeadlessGuard.

### Menu Bar Icon Missing
Restart HeadlessGuard from Applications. If the icon still doesn't appear, check your menu bar settings.

## 🤝 Contributing

HeadlessGuard is open source and welcomes contributions. If you'd like to help improve the app, please visit the GitHub repository to submit issues, feature requests, or pull requests.

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.

## 🙏 Acknowledgments

- Built with Swift and SwiftUI for macOS
- Inspired by the needs of developers using browser automation tools
- Thanks to the open source community for their support

Keywords: apple-silicon, browser-automation, chromium, developer-tools, headless-browser, headless-chrome, macos, macos-app, menu-bar, menubar-app, open-source, playwright, privacy, process-monitor, puppeteer, swift, swiftui, system-utility