import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var detectedLocation: Location?
    @Published var isDetecting = false
    @Published var errorMessage: String?
    @Published var permissionDenied = false

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func detectLocation() {
        isDetecting = true
        errorMessage = nil
        permissionDenied = false

        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            permissionDenied = true
            errorMessage = "Location permission denied. Use manual entry."
            isDetecting = false
            return
        }

        manager.delegate = self
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.requestLocation()
        }
    }

    private func handleLocation(_ clLocation: CLLocation) {
        let geocoder = CLGeocoder()
        let lat = clLocation.coordinate.latitude
        let lon = clLocation.coordinate.longitude
        let alt = clLocation.altitude

        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            let placemark = placemarks?.first
            let name = [placemark?.locality, placemark?.administrativeArea]
                .compactMap { $0 }
                .joined(separator: ", ")
            let tzIdentifier = placemark?.timeZone?.identifier ?? TimeZone.current.identifier

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.detectedLocation = Location(
                    id: "gps",
                    name: name.isEmpty ? "Current Location" : name,
                    lat: lat,
                    lon: lon,
                    elevation: max(0, alt),
                    timezone: tzIdentifier
                )
                self.isDetecting = false
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            handleLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = "Location detection failed: \(error.localizedDescription)"
            isDetecting = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                permissionDenied = true
                errorMessage = "Location permission denied. Use manual entry."
                isDetecting = false
            default:
                break
            }
        }
    }
}
