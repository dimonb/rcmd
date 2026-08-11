import Foundation

/// Headless entry points used by `scripts/install-local.sh`, because the Launch
/// at Login registration can only be made by the app bundle itself.
enum LoginItemCommand: String, CaseIterable, Sendable {
    case enable = "--enable-login-item"
    case disable = "--disable-login-item"

    init?(arguments: [String]) {
        guard
            let command = arguments.dropFirst().lazy.compactMap(LoginItemCommand.init(rawValue:)).first
        else {
            return nil
        }

        self = command
    }

    @MainActor
    func run() -> Int32 {
        let result = LaunchAtLoginController().setEnabled(self == .enable)

        switch result {
        case .enabled, .disabled, .requiresApproval:
            print(result.displayMessage)
            return 0
        case .failed(let message):
            FileHandle.standardError.write(Data("\(message)\n".utf8))
            return 1
        }
    }
}
