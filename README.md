# TarXZ Compressor — iOS App

A SwiftUI iOS app modelled after PKGExtractor. Drop files or folders into
the app's Documents folder via the Files app, tap them, and get a `.tar.xz`
archive compressed at XZ / LZMA2 maximum preset.

---

## Setup in Xcode (5 min)

### 1. Create a new Xcode project

- Open Xcode → **File › New › Project**
- Choose **iOS › App**
- Product Name: `TarXZCompressor`
- Interface: **SwiftUI**
- Language: **Swift**
- Uncheck "Include Tests"
- Save anywhere

### 2. Replace generated files

Delete the default `ContentView.swift` and `<AppName>App.swift` that Xcode
created, then **drag all four `.swift` files** from this folder into the
Xcode project navigator (tick "Copy items if needed"):

```
TarXZCompressorApp.swift
ContentView.swift
CompressionManager.swift
```

### 3. Replace / merge Info.plist

Open your project's `Info.plist` and add these two keys
(or replace the file entirely with the one provided):

| Key | Value |
|-----|-------|
| `UIFileSharingEnabled` | YES |
| `LSSupportsOpeningDocumentsInPlace` | YES |

These two keys make the app's Documents folder visible in the **Files** app.

### 4. Add SWCompression via Swift Package Manager

SWCompression provides the tar container builder and XZ/LZMA2 compressor.

1. In Xcode: **File › Add Package Dependencies…**
2. Paste the URL: `https://github.com/tsolomko/SWCompression`
3. Version rule: **Up to Next Major** from `4.8.0`
4. Add Product: **SWCompression** → target: **TarXZCompressor**

### 5. Set Deployment Target

In the project editor → **TarXZCompressor** target → **General**:
- Minimum Deployments: **iOS 16.0** (or higher)

### 6. Build & Run

Select a simulator or your device and press **⌘R**.

---

## How to use

1. Open the **Files** app on your iPhone.
2. Navigate to **On My iPhone › TarXZCompressor**.
3. Paste any files or folders you want to compress in there.
4. Open **TarXZ Compressor**, tap the item.
5. The `.tar.xz` archive appears in  
   **Files › On My iPhone › TarXZCompressor › Compressed**.

---

## Project structure

```
TarXZCompressor/
├── TarXZCompressorApp.swift   — @main, first-launch README stub
├── ContentView.swift          — SwiftUI list UI + status area
├── CompressionManager.swift   — tar packing + XZ compression logic
├── Info.plist                 — file sharing enabled
├── TarXZCompressor.entitlements
└── Assets.xcassets/
```

---

## Compression details

| Setting | Value |
|---------|-------|
| Container | POSIX tar (ustar) |
| Compression | XZ / LZMA2 |
| Level | Highest (SWCompression default, equivalent to `xz -9`) |
| Extension | `.tar.xz` |

---

## Dependencies

| Package | URL | Use |
|---------|-----|-----|
| SWCompression | https://github.com/tsolomko/SWCompression | tar + XZ |
