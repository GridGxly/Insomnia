import Darwin
import Foundation

/// Launchd starts our signed executable so Login Items can attribute the
/// recovery agent to Insomnia, then we replace it with the verified script.
enum BackstopCommand {
    static let version = 1

    static func run(_ arguments: [String], bundle: URL = Bundle.main.bundleURL) -> Int32? {
        guard arguments.first == "--backstop" else { return nil }
        guard arguments.count == 2, !arguments[1].isEmpty, bundle.pathExtension == "app" else {
            fputs("usage: Insomnia --backstop <code-requirement> (from Insomnia.app)\n", stderr)
            return 64
        }
        let command = ["/bin/sh", "-c", LaunchdBackstop.agentProgram, "sh", arguments[1], bundle.path]
        var argv = command.map { strdup($0) } + [nil]
        defer { for argument in argv { free(argument) } }
        return argv.withUnsafeMutableBufferPointer {
            execv("/bin/sh", $0.baseAddress!)
            perror("Insomnia backstop: exec /bin/sh")
            return 1
        }
    }
}
