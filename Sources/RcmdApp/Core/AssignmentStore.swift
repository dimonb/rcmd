import Foundation

enum KeyMappingMode: String, CaseIterable, Identifiable, Sendable {
    case activeLayout
    case physical

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .activeLayout:
            L10n.tr("keyMapping.activeLayout")
        case .physical:
            L10n.tr("keyMapping.physical")
        }
    }
}

@MainActor
final class AssignmentStore {
    static let defaultOSDShowDelayMilliseconds = 120
    static let osdShowDelayMillisecondsRange = 0...1000

    private(set) var assignmentsByLetter: [Character: String] = [:]
    private(set) var keyMappingMode: KeyMappingMode = .activeLayout
    private(set) var minimizeActiveWindowOnRepeatedShortcut = false
    private(set) var osdShowDelayMilliseconds = AssignmentStore.defaultOSDShowDelayMilliseconds

    private let configURL: URL

    init(configURL: URL = AssignmentStore.defaultConfigURL()) {
        self.configURL = configURL
        load()
    }

    func bundleIdentifier(for letter: Character) -> String? {
        assignmentsByLetter[normalize(letter)]
    }

    func set(bundleIdentifier: String, for letter: Character) {
        assignmentsByLetter[normalize(letter)] = bundleIdentifier
        save()
    }

    func removeAssignment(for letter: Character) {
        assignmentsByLetter.removeValue(forKey: normalize(letter))
        save()
    }

    func setKeyMappingMode(_ mode: KeyMappingMode) {
        keyMappingMode = mode
        save()
    }

    func setMinimizeActiveWindowOnRepeatedShortcut(_ enabled: Bool) {
        minimizeActiveWindowOnRepeatedShortcut = enabled
        save()
    }

    func setOSDShowDelayMilliseconds(_ milliseconds: Int) {
        osdShowDelayMilliseconds = AssignmentStore.clampOSDShowDelay(milliseconds)
        save()
    }

    private func load() {
        guard
            let contents = try? String(contentsOf: configURL, encoding: .utf8),
            !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            assignmentsByLetter = [:]
            return
        }

        var parsedAssignments: [Character: String] = [:]
        var parsedKeyMappingMode = KeyMappingMode.activeLayout
        var parsedMinimizeActiveWindowOnRepeatedShortcut = false
        var parsedOSDShowDelayMilliseconds = AssignmentStore.defaultOSDShowDelayMilliseconds
        var inAssignmentsSection = false

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            if line == "assignments:" {
                inAssignmentsSection = true
                continue
            }

            if !rawLine.hasPrefix(" "), let separatorIndex = line.firstIndex(of: ":") {
                inAssignmentsSection = false

                let key = line[..<separatorIndex].trimmingCharacters(in: .whitespaces)
                let valueStart = line.index(after: separatorIndex)
                let rawValue = line[valueStart...].trimmingCharacters(in: .whitespaces)
                let value = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                if key == "keyMappingMode", let mode = KeyMappingMode(rawValue: value) {
                    parsedKeyMappingMode = mode
                }

                if key == "minimizeActiveWindowOnRepeatedShortcut" {
                    parsedMinimizeActiveWindowOnRepeatedShortcut = value == "true"
                }

                if key == "osdShowDelayMilliseconds", let milliseconds = Int(value) {
                    parsedOSDShowDelayMilliseconds = AssignmentStore.clampOSDShowDelay(milliseconds)
                }

                continue
            }

            guard inAssignmentsSection else {
                continue
            }

            guard
                let separatorIndex = line.firstIndex(of: ":"),
                let letter = line[..<separatorIndex].trimmingCharacters(in: .whitespaces).first
            else {
                continue
            }

            let valueStart = line.index(after: separatorIndex)
            let rawValue = line[valueStart...].trimmingCharacters(in: .whitespaces)
            let bundleIdentifier = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            if !bundleIdentifier.isEmpty {
                parsedAssignments[normalize(letter)] = bundleIdentifier
            }
        }

        assignmentsByLetter = parsedAssignments
        keyMappingMode = parsedKeyMappingMode
        minimizeActiveWindowOnRepeatedShortcut = parsedMinimizeActiveWindowOnRepeatedShortcut
        osdShowDelayMilliseconds = parsedOSDShowDelayMilliseconds
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var lines = [
                "# rcmd configuration",
                "keyMappingMode: \(keyMappingMode.rawValue)",
                "minimizeActiveWindowOnRepeatedShortcut: \(minimizeActiveWindowOnRepeatedShortcut)",
                "osdShowDelayMilliseconds: \(osdShowDelayMilliseconds)",
                "assignments:"
            ]

            for letter in assignmentsByLetter.keys.sorted(by: { String($0) < String($1) }) {
                if let bundleIdentifier = assignmentsByLetter[letter] {
                    lines.append("  \(letter): \(bundleIdentifier)")
                }
            }

            lines.append("")
            try lines.joined(separator: "\n").write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            AppLog.app.error("Failed to save assignments: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func normalize(_ letter: Character) -> Character {
        Character(String(letter).lowercased())
    }

    private static func clampOSDShowDelay(_ milliseconds: Int) -> Int {
        min(max(milliseconds, osdShowDelayMillisecondsRange.lowerBound), osdShowDelayMillisecondsRange.upperBound)
    }

    static func defaultConfigURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("rcmd", isDirectory: true)
            .appendingPathComponent("config.yaml")
    }
}
