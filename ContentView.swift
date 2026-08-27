import SwiftUI

struct ContentView: View {
    @EnvironmentObject var config: Config
    @StateObject var capture = CaptureService()
    @StateObject var bridge = TradeBridge()
    @State private var selecting = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text("AEGIS Capture").font(.title2).bold()
            
            TextField("Server URL", text: $config.serverURL)
            TextField("Account ID", text: $config.accountID)
            SecureField("API Key", text: $config.apiKey)
            
            Button(selecting ? "Drag on Screen..." : "Select Chart Region") {
                selecting.toggle()
                if selecting { capture.startRegionSelect() }
            }
            
            HStack {
                Text("Interval: \(Int(config.intervalSec))s")
                Slider(value: $config.intervalSec, in: 1...10, step: 1)
            }
            
            Button(capture.isRunning ? "STOP" : "START") {
                capture.isRunning ? capture.stop() : capture.start(config: config, bridge: bridge)
            }
            .buttonStyle(.borderedProminent)
            
            Text(bridge.lastSignal ?? "Idle").font(.caption)
        }
        .padding().frame(width: 380)
    }
}
