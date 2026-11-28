import Foundation

/// What a cancelled or timed-out command left running after its cleanup limit. The runner
/// throws `CancellationError` or `ProcessError.timedOut` in that case, so the result cannot
/// carry it; a caller that wants it in its own result hands the runner one of these and reads
/// it back once the work has ended.
public final class OutlivedProcesses: @unchecked Sendable {
    public struct Entry: Sendable, Equatable {
        /// The command as `ProcessCommand.description` spells it, so arguments marked private stay hidden.
        public let command: String
        public let pids: [Int32]

        public init(command: String, pids: [Int32]) {
            self.command = command
            self.pids = pids
        }

        /// One sentence a person can act on: what was left, and that nothing here will wait for it.
        public var summary: String {
            let list = pids.map(String.init).joined(separator: ", ")
            return "Process\(pids.count == 1 ? "" : "es") \(list) started by `\(command)` "
                + "\(pids.count == 1 ? "was" : "were") still running when Runstir stopped waiting after cancellation or timeout. "
                + "Check \(pids.count == 1 ? "it" : "them") and quit \(pids.count == 1 ? "it" : "them") before the next run for this project."
        }
    }

    private let lock = NSLock()
    private var recorded: [Entry] = []

    public init() {}

    public var entries: [Entry] { lock.withLock { recorded } }

    func record(command: String, pids: [Int32]) {
        guard !pids.isEmpty else { return }
        lock.withLock { recorded.append(Entry(command: command, pids: pids)) }
    }
}
