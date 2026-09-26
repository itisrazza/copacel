import Foundation

/// A coarse grouping of file extensions, for answering "what *kind* of thing is filling this
/// disk" — a question the per-extension breakdown answers badly when one kind is spread over
/// several extensions.
public enum FileCategory: String, Sendable, CaseIterable, Identifiable, Hashable {
    case diskImages = "Disk & VM Images"
    case buildOutput = "Binaries & Build Output"
    case archives = "Archives"
    case video = "Video"
    case audio = "Audio"
    case images = "Images"
    case documents = "Documents"
    case code = "Code & Config"
    case other = "Other"

    public var id: Self { self }

    public var systemImage: String {
        switch self {
        case .diskImages: "opticaldiscdrive"
        case .buildOutput: "hammer"
        case .archives: "doc.zipper"
        case .video: "film"
        case .audio: "waveform"
        case .images: "photo"
        case .documents: "doc.text"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .other: "questionmark.folder"
        }
    }

    // Internal so a test can assert no extension is claimed by two categories.
    static let extensionsByCategory: [FileCategory: Set<String>] = [
        .diskImages: [
            "iso", "img", "dmg", "vmdk", "vdi", "vhd", "vhdx", "qcow2", "qcow",
            "sparseimage", "sparsebundle", "nrg", "cdr", "ova", "ovf", "vmem", "vswp", "hds",
            // Split Wii images: .wbfs continues into .wbf1/.wbf2, which belong with it.
            "wbfs", "wbf1", "wbf2",
            // Cartridge and disc dumps — same idea as a disk image, and they run to gigabytes.
            "gba", "gb", "gbc", "smc", "sfc", "nes", "n64", "z64", "v64", "gcm", "rvz",
            "nds", "3ds", "cso", "chd", "gdi", "cdi"
        ],
        .buildOutput: [
            "o", "a", "so", "dylib", "obj", "lib", "pdb", "class", "pyc", "pyo", "rlib",
            "rmeta", "bc", "ko", "swiftmodule", "swiftdoc", "swiftsourceinfo", "d", "gch",
            "dsym", "tlog", "ilk", "exp", "nib",
            // Compiled binaries generally, not just the intermediates.
            "dll", "exe", "node", "pyd", "wasm"
        ],
        .archives: [
            "zip", "tar", "gz", "tgz", "bz2", "tbz", "xz", "7z", "rar", "jar", "war", "aar",
            "pkg", "xip", "cab", "lz4", "zst", "whl", "crate", "nupkg", "pack"
        ],
        .video: [
            // "ts" is deliberately TypeScript, not MPEG transport stream: on a developer's
            // machine the former vastly outnumbers the latter. "m2ts" covers the video case.
            "mp4", "mov", "mkv", "avi", "webm", "m4v", "mpg", "mpeg", "wmv", "flv",
            "m2ts", "vob", "ogv", "prores"
        ],
        .audio: [
            "wav", "aiff", "aif", "flac", "mp3", "m4a", "aac", "ogg", "opus", "wma", "caf",
            "alac", "mid", "midi", "sf2", "sfz"
        ],
        .images: [
            "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp", "svg",
            "ico", "psd", "ai", "raw", "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "avif"
        ],
        .documents: [
            "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "rtf", "pages",
            "numbers", "key", "epub", "mobi", "csv", "tsv", "odt", "ods"
        ],
        .code: [
            "swift", "rs", "go", "py", "js", "mjs", "cjs", "ts", "tsx", "jsx", "c", "h",
            "cpp", "cc", "hpp", "hh", "m", "mm", "java", "kt", "kts", "rb", "php", "cs",
            "sh", "bash", "zsh", "fish", "pl", "lua", "r", "scala", "clj", "ex", "exs",
            "hs", "ml", "vim", "html", "htm", "css", "scss", "sass", "less", "json", "yaml",
            "yml", "toml", "xml", "plist", "sql", "graphql", "proto"
        ]
    ]

    /// Reverse index, built once — the forward map is the readable one to maintain, but
    /// lookups happen per extension in a scan.
    private static let categoryByExtension: [String: FileCategory] = {
        var index: [String: FileCategory] = [:]
        for (category, extensions) in extensionsByCategory {
            for fileExtension in extensions {
                index[fileExtension.lowercased()] = category
            }
        }
        return index
    }()

    /// The category for a lowercased extension. Anything unrecognised — and the empty string,
    /// which stands for a file with no extension at all — lands in ``other``.
    public static func forExtension(_ fileExtension: String) -> FileCategory {
        categoryByExtension[fileExtension.lowercased()] ?? .other
    }
}

public struct CategoryStat: Identifiable, Sendable, Hashable {
    public let category: FileCategory
    public let fileCount: Int
    public let totalLogicalSize: Int64
    public let totalPhysicalSize: Int64
    /// The extensions rolled up here, largest first — so the legend can say what a category
    /// is made of and the treemap can highlight all of them at once.
    public let extensions: [String]

    public var id: FileCategory { category }
}

public enum CategoryStats {
    /// Rolls per-extension totals up into categories. Built from ``ExtensionStat`` rather
    /// than from the tree, so it reuses a walk that's already happened.
    public static func aggregate(from stats: [ExtensionStat]) -> [CategoryStat] {
        var grouped: [FileCategory: [ExtensionStat]] = [:]
        for stat in stats {
            grouped[FileCategory.forExtension(stat.fileExtension), default: []].append(stat)
        }

        return grouped
            .map { category, members in
                CategoryStat(
                    category: category,
                    fileCount: members.reduce(0) { $0 + $1.fileCount },
                    totalLogicalSize: members.reduce(0) { $0 + $1.totalLogicalSize },
                    totalPhysicalSize: members.reduce(0) { $0 + $1.totalPhysicalSize },
                    extensions: members
                        .sorted { $0.totalPhysicalSize > $1.totalPhysicalSize }
                        .map(\.fileExtension)
                )
            }
            .sorted { $0.totalPhysicalSize > $1.totalPhysicalSize }
    }
}
