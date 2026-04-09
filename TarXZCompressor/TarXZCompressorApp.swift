import SwiftUI

@main
struct TarXZCompressorApp: App {

    init() {
        createDocumentsPlaceholder()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// Writes a README into Documents on first launch so the folder
    /// appears in Files app → On My iPhone → TarXZCompressor immediately.
    private func createDocumentsPlaceholder() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let readme = docs.appendingPathComponent("README.txt")
        guard !FileManager.default.fileExists(atPath: readme.path) else { return }
        let text = """
TarXZ Compressor
================
Drop the files or folders you want to compress into this folder
using the Files app, then open TarXZ Compressor and tap an item.

Output lands in:  TarXZCompressor → Compressed → <name>.tar.xz

Compression uses XZ / LZMA2 at the highest preset (level 9)
for maximum space savings.
"""
        try? text.write(to: readme, atomically: true, encoding: .utf8)
    }
}
