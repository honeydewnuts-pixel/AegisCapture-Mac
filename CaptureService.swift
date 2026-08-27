import SwiftUI
import ScreenCaptureKit
import CoreGraphics

class CaptureService: NSObject, ObservableObject, SCStreamDelegate {
    @Published var isRunning = false
    @Published var status = "Idle"
    
    private var stream: SCStream?
    private var config = Config()
    private var bridge: TradeBridge?
    private var timer: Timer?
    
    func startRegionSelect() {
        status = "Click and drag to select region on screen"
        // For v1 we use saved coords. v2 we can add overlay drag.
        // To change region: open app, change values in config, restart
    }
    
    func start(config: Config, bridge: TradeBridge) {
        self.config = config
        self.bridge = bridge
        isRunning = true
        status = "Starting capture..."
        
        requestPermissionAndStart()
        
        timer = Timer.scheduledTimer(withTimeInterval: config.intervalSec, repeats: true) { _ in
            Task { await self.captureFrame() }
        }
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        stream = nil
        status = "Stopped"
    }
    
    private func requestPermissionAndStart() {
        Task {
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first else { return }
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let configuration = SCStreamConfiguration()
                configuration.width = Int(config.regionW)
                configuration.height = Int(config.regionH)
                configuration.sourceRect = CGRect(x: config.regionX, y: config.regionY, width: config.regionW, height: config.regionH)
                configuration.showsCursor = false
                
                stream = SCStream(filter: filter, configuration: configuration, delegate: self)
                try await stream?.startCapture()
                await MainActor.run { self.status = "Capturing region" }
            } catch {
                await MainActor.run { self.status = "Error: \(error.localizedDescription)" }
            }
        }
    }
    
    private func captureFrame() async {
        // SCStream gives us frames automatically. For v1 we do a manual screenshot
        guard let bridge = bridge else { return }
        
        let rect = CGRect(x: config.regionX, y: config.regionY, width: config.regionW, height: config.regionH)
        
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .boundsIgnoreFraming
        ) else { return }
        
        let nsImage = NSImage(cgImage: cgImage, size: rect.size)
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return }
        
        await bridge.sendFrame(imageData: pngData, config: config)
        await MainActor.run { self.status = "Sent frame at \(Date().formatted(date: .omitted, time: .standard))" }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {}
}
