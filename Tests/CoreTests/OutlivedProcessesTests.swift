import Foundation
import Logging
import Testing

@testable import Core

// A process that survives SIGKILL cannot be made on a real host, so the table is a fake: the
// command is a real `sleep`, and one descendant of it that no signal removes is made up.
@Suite("SystemProcessRunner reports what outlived its cleanup limit")
struct OutlivedProcessesTests {
    final class StuckDescendant: @unchecked Sendable {
        static let pid: Int32 = 2_000_000_001
        private let lock = NSLock()
        private var root: Int32?

        /// True once the runner has read the command's own process, which is when a cancellation
        /// can first find the descendant.
        var adopted: Bool { lock.withLock { root != nil } }

        var table: ProcessTable {
            ProcessTable(
                entry: { pid in
                    if pid == Self.pid {
                        return ProcessEntry(identity: ProcessIdentity(pid: pid, started: UInt64.max - 1),
                                            parent: self.lock.withLock { self.root } ?? 0)
                    }
                    // The command itself. kill(pid, 0) also succeeds on a zombie, unlike the real table, so this
                    // relies on the runner having reaped the command before it settles.
                    guard kill(pid, 0) == 0 else { return nil }
                    self.lock.withLock { if self.root == nil { self.root = pid } }
                    return ProcessEntry(identity: ProcessIdentity(pid: pid, started: 1), parent: 1)
                },
                children: { pid in self.lock.withLock { pid == self.root ? [Self.pid] : [] } },
                signal: { _, _ in }
            )
        }
    }

    @Test("a descendant still running after the limit is recorded for the caller, on timeout and on cancellation",
          arguments: [false, true])
    func recordsSurvivor(_ timeout: Bool) async throws {
        let sink = OutlivedProcesses()
        let stuck = StuckDescendant()
        let runner = SystemProcessRunner(logger: Logger(label: "outlived-test"), environment: ["PATH": "/usr/bin:/bin"],
                                         workingDirectory: nil, outlived: sink, table: stuck.table,
                                         settleLimit: .milliseconds(100))
        let command = ProcessCommand("/bin/sleep", ["30"], timeout: timeout ? .seconds(2) : nil)
        let task = Task { try await runner.run(command) }
        if !timeout {
            let ready = ContinuousClock.now + .seconds(30)
            while !stuck.adopted, ContinuousClock.now < ready { try await Task.sleep(for: .milliseconds(10)) }
            // The fake sees the command before the runner records it as its root.
            try await Task.sleep(for: .milliseconds(500))
            task.cancel()
        }
        do {
            _ = try await task.value
            Issue.record("the interrupted command must not succeed")
        } catch let error as ProcessError {
            guard case .timedOut = error else { throw error }
            #expect(timeout)
        } catch is CancellationError {
            #expect(!timeout)
        }

        #expect(sink.entries == [OutlivedProcesses.Entry(executable: "sleep", pids: [StuckDescendant.pid])])
    }

    @Test("a command that ends on its own records nothing")
    func normalRunRecordsNothing() async throws {
        let sink = OutlivedProcesses()
        let runner = SystemProcessRunner(outlived: sink)
        let result = try await runner.run(ProcessCommand("/bin/echo", ["ok"]))
        #expect(result.terminationStatus.isSuccess)
        #expect(sink.entries.isEmpty)
    }

    @Test("an entry names only the program and at most a few processes, never the arguments")
    func summaryNamesProgramAndLimitsProcesses() {
        let few = OutlivedProcesses.Entry(executable: "xcodebuild", pids: [41, 42])
        #expect(few.summary.contains("41, 42"))
        #expect(few.summary.contains("`xcodebuild`"))
        #expect(OutlivedProcesses.Entry(executable: "x", pids: [7]).summary.hasPrefix("Process 7 started"))
        let many = OutlivedProcesses.Entry(executable: "x", pids: Array(1...12))
        #expect(many.summary.contains("1, 2, 3, 4, 5, and 7 more"))
        #expect(!many.summary.contains("12"))
    }
}
