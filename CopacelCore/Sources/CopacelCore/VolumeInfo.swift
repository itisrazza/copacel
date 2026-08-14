import Foundation

/// A locally mounted volume, as reported by ``VolumeInfo/mountedVolumes()``.
public struct VolumeInfo: Identifiable, Sendable, Equatable, Hashable {
    public let url: URL
    public let name: String
    public let capacity: Int64?
    public let available: Int64?
    public let isBootVolume: Bool
    public let isRemovable: Bool

    public init(
        url: URL,
        name: String,
        capacity: Int64?,
        available: Int64?,
        isBootVolume: Bool,
        isRemovable: Bool
    ) {
        self.url = url
        self.name = name
        self.capacity = capacity
        self.available = available
        self.isBootVolume = isBootVolume
        self.isRemovable = isRemovable
    }

    public var id: URL { url }

    public var usedSpace: Int64? {
        guard let capacity, let available else { return nil }
        return capacity - available
    }

    public var usedPercentage: Double? {
        guard let capacity, capacity > 0, let used = usedSpace else { return nil }
        return (Double(used) / Double(capacity)) * 100
    }

    public var formattedCapacity: String? {
        guard let capacity else { return nil }
        return ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file)
    }

    public var formattedUsedSpace: String {
        guard let used = usedSpace else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: used, countStyle: .file) + " used"
    }
}

extension VolumeInfo {
    /// Orders volumes boot-first, then internal drives before removable ones, then
    /// alphabetically by name. Pulled out as a pure function so ordering can be unit
    /// tested without touching the filesystem.
    public static func sorted(_ volumes: [VolumeInfo]) -> [VolumeInfo] {
        volumes.sorted { lhs, rhs in
            if lhs.isBootVolume != rhs.isBootVolume {
                return lhs.isBootVolume
            }
            if lhs.isRemovable != rhs.isRemovable {
                return !lhs.isRemovable
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// Enumerates locally mounted, non-hidden volumes and returns them via ``sorted(_:)``.
    public static func mountedVolumes() -> [VolumeInfo] {
        let fileManager = FileManager.default

        guard let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [
                .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
                .volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey, .volumeIsLocalKey
            ],
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        let bootVolumeURL = URL(fileURLWithPath: "/")

        let volumes = urls.compactMap { url -> VolumeInfo? in
            guard let values = try? url.resourceValues(forKeys: [
                .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
                .volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsLocalKey
            ]) else {
                return nil
            }
            guard values.volumeIsLocal == true else { return nil }

            return VolumeInfo(
                url: url,
                name: values.volumeName ?? url.lastPathComponent,
                capacity: values.volumeTotalCapacity.map { Int64($0) },
                available: values.volumeAvailableCapacity.map { Int64($0) },
                isBootVolume: url.path == bootVolumeURL.path,
                isRemovable: values.volumeIsRemovable == true || values.volumeIsEjectable == true
            )
        }

        return sorted(volumes)
    }
}
