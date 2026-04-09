import SwiftUI

struct ContentView: View {
    @StateObject private var manager = CompressionManager()
    @State private var items: [URL] = []
    @State private var selectedURL: URL? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // ── Header ─────────────────────────────────────────────
                VStack(spacing: 8) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.indigo)
                        .padding(.top, 32)

                    Text("TarXZ Compressor")
                        .font(.largeTitle.bold())

                    Text("Copy files or folders into this app's folder in Files,\nthen tap an item below to compress it.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                Divider()

                // ── File / folder list ─────────────────────────────────
                if items.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No items found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Open Files app → On My iPhone → TarXZCompressor\nand paste your files or folders there.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button(action: refreshList) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                } else {
                    List(items, id: \.path) { url in
                        ItemRow(url: url,
                                isSelected: selectedURL == url,
                                manager: manager) {
                            startCompression(url: url)
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Divider()

                // ── Status area ────────────────────────────────────────
                statusArea
                    .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshList) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(manager.isCompressing)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Open Files") {
                        if let url = URL(string: "shareddocuments://") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
        .onAppear(perform: refreshList)
    }

    // ── Status area ────────────────────────────────────────────────────
    @ViewBuilder
    private var statusArea: some View {
        if manager.isCompressing {
            VStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(1.3)
                Text("Compressing…")
                    .font(.headline)
                if !manager.currentFile.isEmpty {
                    Text(manager.currentFile)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 16) {
                    Label("\(manager.fileCount) files", systemImage: "doc")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Label(ByteCountFormatter.string(fromByteCount: manager.bytesTotal, countStyle: .file),
                          systemImage: "internaldrive")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

        } else if manager.finished {
            if let err = manager.lastError {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Compression failed", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.headline)
                    ScrollView {
                        Text(err)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            } else {
                VStack(spacing: 6) {
                    Label("Done — \(manager.fileCount) files packed",
                          systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                    if let out = manager.outputURL {
                        Text(out.lastPathComponent)
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(ByteCountFormatter.string(
                            fromByteCount: (try? out.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                                .flatMap { Int64($0) } ?? 0,
                            countStyle: .file))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text("Output is in TarXZCompressor → Compressed in Files app")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

        } else {
            Text("Files app → On My iPhone → TarXZCompressor → paste items here")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────
    private func refreshList() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey,
                                          .contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        items = contents
            .filter { url in
                // Hide the README we created, and already-compressed archives
                url.lastPathComponent != "README.txt" &&
                url.lastPathComponent != "Compressed" &&
                url.pathExtension.lowercased() != "xz"
            }
            .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
    }

    private func startCompression(url: URL) {
        guard !manager.isCompressing else { return }
        selectedURL = url
        manager.compress(sourceURL: url)
    }
}

// ── Per-row component ──────────────────────────────────────────────────
struct ItemRow: View {
    let url:        URL
    let isSelected: Bool
    let manager:    CompressionManager
    let onTap:      () -> Void

    @State private var subtitle: String = ""
    @State private var isDir:    Bool   = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: isDir ? "folder.fill" : "doc.fill")
                    .font(.title2)
                    .foregroundColor(isDir ? .orange : .indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected && manager.isCompressing {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(manager.isCompressing)
        .onAppear(perform: loadMeta)
    }

    private func loadMeta() {
        guard let resVals = try? url.resourceValues(
            forKeys: [.isDirectoryKey, .fileSizeKey]) else { return }

        isDir = resVals.isDirectory ?? false

        if isDir {
            // Count top-level items for the subtitle
            let count = (try? FileManager.default.contentsOfDirectory(
                atPath: url.path))?.count ?? 0
            subtitle = "\(count) item\(count == 1 ? "" : "s")"
        } else if let bytes = resVals.fileSize {
            subtitle = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        }
    }
}

#Preview {
    ContentView()
}
