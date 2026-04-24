import Foundation
import Combine

class RateLimitHistoryLoader: ObservableObject {
    @Published private(set) var stats: QuotaStats?

    private var watcher: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let csvFile: URL

    init() {
        csvFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/rate-limit-history.csv")
    }

    func start() {
        reload()

        let dir = csvFile.deletingLastPathComponent()
        fileDescriptor = open(dir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.reload()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
        source.resume()
        watcher = source
    }

    func stop() {
        watcher?.cancel()
        watcher = nil
    }

    private func reload() {
        guard let csv = try? String(contentsOf: csvFile, encoding: .utf8) else {
            stats = nil
            return
        }
        let entries = RateLimitHistoryParser.parse(csv: csv)
        stats = RateLimitHistoryParser.compute(from: entries)
    }

    deinit {
        stop()
    }
}
