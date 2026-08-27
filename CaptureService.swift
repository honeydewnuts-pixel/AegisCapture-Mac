import SwiftUI
import ScreenCaptureKit

class CaptureService: NSObject, ObservableObject {
    @Published var isRunning = false
    private var timer: Timer?
    
    func startRegionSelect() {
        // Simple: use fixed region for now. We can add drag overlay later
        print("Region select: Using saved region")
    }
    
    func start(config: Config, bridge: TradeBridge) {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: config.intervalSec, repeats: true) { _ in
            Task { await self.captureAndSend(config: config, bridge: bridge) }
        }
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func captureAndSend(config: Config, bridge: TradeBridge) async {
        // TODO: Replace with actual SCShareableContent + CGImage crop
        // For now send dummy
        await bridge.sendPing()
    }
}
