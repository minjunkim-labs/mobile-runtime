import Foundation

/// What a cancelled or timed-out command left running after its cleanup limit. The runner
/// throws `CancellationError` or `ProcessError.timedOut` in that case, so the result cannot
/// carry it; a caller that wants it in its own result hands the runner one of these and reads
/// it back once the work has ended.
public final class OutlivedProcesses: @unchecked Sendable {
    public struct Entry: Sendable, Equatable {
        /// Only the program's file name. The full command line can carry private paths and
        /// arguments from the project, and this ends up in results people paste into issues.
        public let executable: String
        public let pids: [Int32]

        public init(executable: String, pids: [Int32]) {
            self.executable = executable
            self.pids = pids
        }

        /// At most this many pids are named; a runaway tree must not make one huge sentence.
        static let namedLimit = 5

        /// One sentence a person can act on: what was left, and that nothing here will wait for it.
        public var summary: String {
            let one = pids.count == 1
            var list = pids.prefix(Self.namedLimit).map(String.init).joined(separator: ", ")
            if pids.count > Self.namedLimit { list += ", and \(pids.count - Self.namedLimit) more" }
            return "Process\(one ? "" : "es") \(list) started by `\(executable)` \(one ? "was" : "were") "
                + "still running when Runstir stopped waiting after cancellation or timeout. "
                + "Check \(one ? "it" : "them") and quit \(one ? "it" : "them") before the next run for this project."
        }
    }

    private let lock = NSLock()
    private var recorded: [Entry] = []

    public init() {}

    public var entries: [Entry] { lock.withLock { recorded } }

    func record(executable: String, pids: [Int32]) {
        guard !pids.isEmpty else { return }
        lock.withLock { recorded.append(Entry(executable: executable, pids: pids)) }
    }
}
