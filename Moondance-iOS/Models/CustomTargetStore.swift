import Foundation
import Observation

@Observable
final class CustomTargetStore {
    private(set) var targets: [Target] = []

    static let shared = CustomTargetStore()

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("custom_targets.json")
    }()

    private init() {
        load()
    }

    func add(_ target: Target) {
        guard !targets.contains(where: { $0.id == target.id }) else { return }
        targets.append(target)
        save()
    }

    func addAll(_ newTargets: [Target]) {
        // Deduplicate by name + RA + Dec to avoid re-import doubles
        let existing = Set(targets.map { "\($0.name)|\($0.ra)|\($0.dec)" })
        let unique = newTargets.filter { !existing.contains("\($0.name)|\($0.ra)|\($0.dec)") }
        targets.append(contentsOf: unique)
        save()
    }

    func remove(_ target: Target) {
        targets.removeAll { $0.id == target.id }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Target].self, from: data) else {
            targets = []
            return
        }
        targets = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(targets) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
