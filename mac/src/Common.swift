import Foundation

/// Esito di un'operazione di rete o di sistema (stesso ruolo di OpResult in NetOps.cs).
struct OpResult {
    var ok: Bool
    var message: String
    init(_ ok: Bool, _ message: String) { self.ok = ok; self.message = message }
}

/// Flag diagnostici e logging, equivalenti a Program.cs.
enum Program {
    static let debugOn = ProcessInfo.processInfo.environment["NETSWITCH_DEBUG"] == "1"
    static let noAutoHide = ProcessInfo.processInfo.environment["NETSWITCH_NOHIDE"] == "1"
    /// Interfacce e configurazioni fittizie (screenshot della documentazione).
    static let fake = debugOn && ProcessInfo.processInfo.environment["NETSWITCH_FAKE"] == "1"

    static func debug(_ s: String) {
        guard debugOn else { return }
        let line = currentTimeString() + " " + s + "\n"
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("netswitch_debug.log")
        appendText(line, to: path)
    }

    private static func appendText(_ text: String, to path: String) {
        guard let data = text.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: path) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }

    private static func currentTimeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}

func truncate(_ s: String, _ max: Int) -> String {
    if s.count <= max { return s }
    let idx = s.index(s.startIndex, offsetBy: max - 1)
    return String(s[..<idx]) + "…"
}
