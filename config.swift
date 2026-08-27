import Foundation

class Config: ObservableObject {
    @AppStorage("server_url") var serverURL = "https://aegis-api-0z1p.onrender.com"
    @AppStorage("account_id") var accountID = ""
    @AppStorage("api_key") var apiKey = ""
    @AppStorage("device_id") var deviceID = "mac-" + UUID().uuidString.prefix(10)
    @AppStorage("interval_sec") var intervalSec = 3.0
    
    @AppStorage("region_x") var regionX = 200.0
    @AppStorage("region_y") var regionY = 150.0
    @AppStorage("region_w") var regionW = 640.0
    @AppStorage("region_h") var regionH = 400.0
}
