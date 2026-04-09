import Foundation
import SWCompression

// MARK: - CompressionManager

@MainActor
class CompressionManager: ObservableObject {

    // ── Published state ────────────────────────────────────────────────
    @Published var isCompressing  = false
    @Published var currentFile:  String = ""
    @Published var fileCount:    Int    = 0
    @Published var bytesTotal:   Int64  = 0
    @Published var lastError:    String? = nil
    @Published var finished      = false
    @Published var outputURL:    URL?   = nil

    // ── Public entry point ─────────────────────────────────────────────

    /// Compress `sourceURL` (file or directory) into a .tar.xz archive
    /// placed in Documents/Compressed/<name>.tar.xz.
    func compress(sourceURL: URL) {
        guard !isCompressing else { return }

        isCompressing = true
        finished      = false
        lastError     = nil
        currentFile   = ""
        fileCount     = 0
        bytesTotal    = 0
        outputURL     = nil

        let docs      = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outDir    = docs.appendingPathComponent("Compressed")
        let stem      = sourceURL.deletingPathExtension().lastPathComponent
        let outFile   = outDir.appendingPathComponent("\(stem).tar.xz")

        Task.detached(priority: .userInitiated) {
            do {
                // 1 – Collect all entries
                let entries = try await self.buildEntries(from: sourceURL)

                // 2 – Pack into tar
                let tarData = try TarContainer.create(from: entries)

                // 3 – Compress to XZ (LZMA2, highest preset via SWCompression)
                let xzData  = try XZArchive.archive(data: tarData)

                // 4 – Write output
                try FileManager.default.createDirectory(at: outDir,
                    withIntermediateDirectories: true)
                try xzData.write(to: outFile, options: .atomic)

                await MainActor.run {
                    self.isCompressing = false
                    self.finished      = true
                    self.outputURL     = outFile
                }

            } catch {
                await MainActor.run {
                    self.isCompressing = false
                    self.finished      = true
                    self.lastError     = error.localizedDescription
                }
            }
        }
    }

    // ── Private helpers ────────────────────────────────────────────────

    /// Recursively walk `root` and return one TarEntry per file/symlink/dir.
    private func buildEntries(from root: URL) async throws -> [TarEntry] {
        var entries: [TarEntry] = []
        let fm = FileManager.default
        let rootName = root.lastPathComponent

        var isDir: ObjCBool = false
        fm.fileExists(atPath: root.path, isDirectory: &isDir)

        if isDir.boolValue {
            // Add a directory entry for the root itself
            var dirInfo        = TarEntryInfo(name: rootName + "/", type: .directory)
            dirInfo.permissions = Permissions(rawValue: 0o755)
            entries.append(TarEntry(info: dirInfo, data: nil))

            // Enumerate contents
            let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey,
                                             .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            while let item = enumerator?.nextObject() as? URL {
                let resVals = try item.resourceValues(forKeys: [
                    .isDirectoryKey, .isSymbolicLinkKey,
                    .fileSizeKey, .contentModificationDateKey
                ])
                let relPath = rootName + "/" + (item.path
                    .replacingOccurrences(of: root.path + "/", with: ""))

                // Report progress back to main actor
                let shortName = item.lastPathComponent
                await MainActor.run {
                    self.currentFile = shortName
                    self.fileCount  += 1
                }

                if resVals.isSymbolicLink == true {
                    let dest = try fm.destinationOfSymbolicLink(atPath: item.path)
                    var info            = TarEntryInfo(name: relPath, type: .symbolicLink)
                    info.linkName       = dest
                    info.permissions    = Permissions(rawValue: 0o777)
                    info.modificationTime = resVals.contentModificationDate
                    entries.append(TarEntry(info: info, data: nil))

                } else if resVals.isDirectory == true {
                    var info        = TarEntryInfo(name: relPath + "/", type: .directory)
                    info.permissions = Permissions(rawValue: 0o755)
                    info.modificationTime = resVals.contentModificationDate
                    entries.append(TarEntry(info: info, data: nil))

                } else {
                    let data = try Data(contentsOf: item)
                    var info = TarEntryInfo(name: relPath, type: .regular)
                    info.size = data.count
                    info.permissions    = Permissions(rawValue: 0o644)
                    info.modificationTime = resVals.contentModificationDate
                    entries.append(TarEntry(info: info, data: data))

                    await MainActor.run {
                        self.bytesTotal += Int64(data.count)
                    }
                }
            }

        } else {
            // Single file
            let data = try Data(contentsOf: root)
            var info = TarEntryInfo(name: rootName, type: .regular)
            info.size = data.count
            info.permissions  = Permissions(rawValue: 0o644)
            entries.append(TarEntry(info: info, data: data))

            await MainActor.run {
                self.currentFile = rootName
                self.fileCount   = 1
                self.bytesTotal  = Int64(data.count)
            }
        }

        return entries
    }
}
