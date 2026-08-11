import AppKit

@main
enum Main {
    @MainActor
    static func main() {
        if let command = LoginItemCommand(arguments: CommandLine.arguments) {
            exit(command.run())
        }

        let app = NSApplication.shared
        let delegate = RcmdApp()
        app.delegate = delegate
        app.run()
    }
}
