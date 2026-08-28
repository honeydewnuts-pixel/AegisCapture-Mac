import Foundation
import ScreenCaptureKit
import AppKit
import CoreMedia

@MainActor
class CaptureService: NSObject, ObservableObject, SCStreamDelegate, SCStreamOutput {
    @Published var isRunning = false
    @Published var status = "Idle — grant Screen Recording, then Start"

    private var timer: Timer?
    private var config: Config?
    private var bridge: TradeBridge?

    func start(config: Config, bridge: TradeBridge) {
        self.config = config
        self.bridge = bridge
        isRunning = true
        status = "Capturing every \(Int(config.intervalSec))s"
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: max(2.0, config.intervalSec), repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.captureOnce()
            }
        }
        Task { await captureOnce() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        status = "Stopped"
    }

    private func captureOnce() async {
        guard let config, let bridge else { return }
        let rect = CGRect(x: config.regionX, y: config.regionY, width: config.regionW, height: config.regionH)
        // CGWindowListCreateImage is deprecated but simple for region capture on macOS.
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.boundsIgnoreFraming]
        ) else {
            status = "Capture failed — check Screen Recording permission"
            return
        }
        let nsImage = NSImage(cgImage: cgImage, size: rect.size)
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return }
        await bridge.sendFrame(imageData: pngData, config: config)
        status = "Last frame \(Date().formatted(date: .omitted, time: .standard))"
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {}
}
