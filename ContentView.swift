import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var config: Config
    @StateObject var bridge = TradeBridge()
    @StateObject var capture = CaptureService()
    @State private var showGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AEGIS Capture — macOS")
                .font(.title2.bold())
                .foregroundColor(Color(red: 0, green: 0.88, blue: 0.75))

            Group {
                TextField("Server URL", text: $config.serverURL)
                TextField("Account ID", text: $config.accountID)
                SecureField("API Key", text: $config.apiKey)
                HStack {
                    Text("Interval (sec)")
                    TextField("5", value: $config.intervalSec, format: .number)
                        .frame(width: 60)
                }
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Button("Color Guide") { showGuide = true }
                Button(capture.isRunning ? "Stop" : "Start") {
                    if capture.isRunning {
                        capture.stop()
                    } else {
                        capture.start(config: config, bridge: bridge)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }

            Text("Signal: \(bridge.lastSignal)")
                .font(.headline)
            Text("HTTP \(bridge.lastHTTP) · frames \(bridge.frames) · uploads \(bridge.uploadsOK)")
                .foregroundColor(.secondary)
            Text(capture.status)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Grant Screen Recording permission. Keep MT5 chart visible in the capture region.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 420)
        .sheet(isPresented: $showGuide) {
            ColorGuideView()
        }
    }
}

struct ColorGuideView: View {
    var body: some View {
        VStack {
            Text("AEGIS MT5 Color Match Guide")
                .font(.headline)
                .padding()
            if let url = Bundle.main.url(forResource: "mt5_color_match_guide", withExtension: "jpg"),
               let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 700, maxHeight: 900)
            } else if let path = Bundle.main.path(forResource: "mt5_color_match_guide", ofType: "jpg"),
                      let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Guide image missing from app bundle. See guides/mt5_color_match_guide.jpg in the repo.")
                    .padding()
            }
            Button("Close") { NSApp.keyWindow?.close() }
                .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}
