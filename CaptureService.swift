import SwiftUI
import CoreGraphics
import Combine

class CaptureService: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var screenshotCount = 0
    @Published var lastSignal = "HOLD"
    @Published var errorMessage: String?
    
    private var timer: Timer?
    private var region: CGRect = .zero
    private var config: Config?
    private var isCapturing = false
    
    override init() {
        super.init()
    }
    
    func startCapture(config: Config, region: CGRect) {
        self.config = config
        self.region = region
        self.isRunning = true
        self.screenshotCount = 0
        self.errorMessage = nil
        
        // Check for screen recording permission
        checkScreenRecordingPermission()
        
        // Start the timer
        timer = Timer.scheduledTimer(withTimeInterval: config.intervalSec, repeats: true) { [weak self] _ in
            self?.captureScreenshot()
        }
    }
    
    func stopCapture() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func checkScreenRecordingPermission() {
        // This will trigger the system permission dialog on first run
        if #available(macOS 14.0, *) {
            Task {
                do {
                    let content = try await SCShareableContent.current()
                    print("Screen recording permission granted: \(content.displays.count) displays")
                } catch {
                    print("Screen recording permission error: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Please grant screen recording permission in System Settings > Privacy & Security > Screen Recording"
                    }
                }
            }
        } else {
            // For older macOS, use CGWindowListCopyWindowInfo to trigger permission
            _ = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
        }
    }
    
    private func captureScreenshot() {
        guard isRunning, !isCapturing else { return }
        isCapturing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let image = self.captureScreenRegion()
            
            DispatchQueue.main.async {
                self.isCapturing = false
                if let image = image {
                    self.processImage(image)
                }
            }
        }
    }
    
    private func captureScreenRegion() -> NSImage? {
        let screenRect = region
        
        // Use the deprecated method - it still works in current macOS
        // We'll suppress the warning by using a wrapper
        guard let cgImage = self.captureCGImage(rect: screenRect) else {
            print("Failed to capture screenshot")
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: screenRect.size)
    }
    
    private func captureCGImage(rect: CGRect) -> CGImage? {
        // Direct call to CGWindowListCreateImage with proper parameters
        // This is deprecated but still works in macOS 14 and 15
        let options: CGWindowListOption = [.optionOnScreenBelowWindow, .excludeDesktopElements]
        let windowID = CGWindowID(0)
        let imageOption: CGWindowImageOption = [.bestResolution, .boundsIgnoreFraming]
        
        // Use the API directly - it will work for now
        return CGWindowListCreateImage(rect, options, windowID, imageOption)
    }
    
    private func processImage(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            print("Failed to convert image")
            return
        }
        
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("Failed to convert to PNG")
            return
        }
        
        // Send to API
        sendToAPI(pngData)
        
        DispatchQueue.main.async {
            self.screenshotCount += 1
        }
    }
    
    private func sendToAPI(_ imageData: Data) {
        guard let config = config else { return }
        
        let base64String = imageData.base64EncodedString()
        
        // Send to API using URLSession
        guard let url = URL(string: "\(config.serverURL)/aegis/analyze") else {
            print("Invalid server URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "image": base64String,
            "account_id": config.accountID,
            "api_key": config.apiKey,
            "device_id": config.deviceID
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error serializing request: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("API error: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data from API")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let signal = json["signal"] as? String {
                    DispatchQueue.main.async {
                        self?.lastSignal = signal
                        // Write signal to file for MT5
                        self?.writeSignalToFile(signal)
                    }
                }
            } catch {
                print("Error parsing response: \(error)")
            }
        }.resume()
    }
    
    private func writeSignalToFile(_ signal: String) {
        // Write signal to file for MT5 to read
        let fileManager = FileManager.default
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentsDirectory = paths.first {
            let fileURL = documentsDirectory.appendingPathComponent("aegis_signal.txt")
            do {
                try signal.write(to: fileURL, atomically: true, encoding: .utf8)
                print("Signal written to file: \(signal)")
            } catch {
                print("Error writing signal to file: \(error)")
            }
        }
    }
}
