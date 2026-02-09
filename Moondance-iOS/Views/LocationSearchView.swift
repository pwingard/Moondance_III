import SwiftUI
import MapKit
import CoreLocation

/// A searchable view for finding locations by address/place name
struct LocationSearchView: View {
    @Binding var selectedLocation: Location?
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @State private var isSearching = false
    @State private var completerDelegate: SearchCompleterDelegate?

    var body: some View {
        List {
            if results.isEmpty && !searchText.isEmpty {
                if isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No results found")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(results, id: \.self) { result in
                    Button {
                        selectResult(result)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(result.title)
                                .foregroundColor(.primary)
                            Text(result.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search for a city or address")
        .onChange(of: searchText) { _, newValue in
            search(query: newValue)
        }
        .navigationTitle("Search Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
        .onAppear {
            setupCompleter()
        }
    }

    private func setupCompleter() {
        let delegate = SearchCompleterDelegate { completions in
            self.results = completions
            self.isSearching = false
        }
        self.completerDelegate = delegate
    }

    private func search(query: String) {
        guard !query.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        completerDelegate?.search(query: query)
    }

    private func selectResult(_ result: MKLocalSearchCompletion) {
        Task {
            let request = MKLocalSearch.Request(completion: result)
            let search = MKLocalSearch(request: request)

            do {
                let response = try await search.start()
                guard let mapItem = response.mapItems.first else { return }

                let coordinate = mapItem.placemark.coordinate
                let name = [mapItem.placemark.locality, mapItem.placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                let displayName = name.isEmpty ? result.title : name

                // Get timezone - try MapKit first, then CLGeocoder as fallback
                var timezone = mapItem.timeZone?.identifier
                if timezone == nil {
                    // Use CLGeocoder to get timezone
                    let geocoder = CLGeocoder()
                    let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    if let placemarks = try? await geocoder.reverseGeocodeLocation(clLocation),
                       let tz = placemarks.first?.timeZone?.identifier {
                        timezone = tz
                    }
                }
                // Final fallback: estimate from longitude (rough approximation)
                if timezone == nil {
                    let offsetHours = Int(round(coordinate.longitude / 15.0))
                    timezone = "Etc/GMT\(offsetHours >= 0 ? "-" : "+")\(abs(offsetHours))"
                }

                let location = Location(
                    id: "search-\(UUID().uuidString)",
                    name: displayName,
                    lat: coordinate.latitude,
                    lon: coordinate.longitude,
                    elevation: 0,
                    timezone: timezone ?? TimeZone.current.identifier
                )

                await MainActor.run {
                    selectedLocation = location
                    isPresented = false
                }
            } catch {
                print("Location search error: \(error)")
            }
        }
    }
}

/// Delegate wrapper that handles MKLocalSearchCompleter callbacks
private class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private let onResults: @MainActor ([MKLocalSearchCompletion]) -> Void

    init(onResults: @escaping @MainActor ([MKLocalSearchCompletion]) -> Void) {
        self.onResults = onResults
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            onResults(results)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error)")
        Task { @MainActor in
            onResults([])
        }
    }
}
