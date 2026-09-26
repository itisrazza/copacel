import AppKit
import CopacelCore
import SwiftUI

struct VolumeSelectionView: View {
    let onSelectVolume: (URL) -> Void
    let onChooseFolder: () -> Void

    @State private var volumes: [VolumeInfo] = []
    @State private var hasFullDiskAccess = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Choose What to Scan")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Start with your own files, or scan a whole volume")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
            .padding(.bottom, hasFullDiskAccess ? 32 : 16)

            if !hasFullDiskAccess {
                FullDiskAccessPrompt()
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            ScrollView {
                VStack(spacing: 12) {
                    // Offered first because it's usually what's wanted: a whole-volume scan
                    // buries your own files under system folders you can't do anything about.
                    HomeFolderRow {
                        onSelectVolume(FileManager.default.homeDirectoryForCurrentUser)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    ForEach(volumes) { volume in
                        VolumeRow(volume: volume) {
                            onSelectVolume(volume.url)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: 600)
            Spacer()
            VStack(spacing: 8) {
                Text("Or choose a specific folder:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    onChooseFolder()
                } label: {
                    Label("Choose Folder…", systemImage: "folder.badge.plus")
                }
                .controlSize(.large)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .task {
            refreshVolumes()
            hasFullDiskAccess = FullDiskAccess.isGranted()
        }
        // Re-check on activation: the usual path here is to leave for System Settings, grant
        // it, and come back, and the notice should be gone on return.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFullDiskAccess = FullDiskAccess.isGranted()
        }
        .task {
            await observeVolumeChanges()
        }
    }

    @MainActor
    private func refreshVolumes() {
        volumes = VolumeInfo.mountedVolumes()
    }

    @MainActor
    private func observeVolumeChanges() async {
        let center = NSWorkspace.shared.notificationCenter
        async let mounts: Void = observe(center.notifications(named: NSWorkspace.didMountNotification))
        async let unmounts: Void = observe(center.notifications(named: NSWorkspace.didUnmountNotification))
        async let renames: Void = observe(center.notifications(named: NSWorkspace.didRenameVolumeNotification))
        _ = await (mounts, unmounts, renames)
    }

    @MainActor
    private func observe(_ notifications: NotificationCenter.Notifications) async {
        for await _ in notifications {
            refreshVolumes()
        }
    }
}

private extension VolumeInfo {
    var icon: String {
        if isRemovable {
            "externaldrive"
        } else if isBootVolume {
            "internaldrive.fill"
        } else {
            "internaldrive"
        }
    }

    var iconColor: Color {
        isBootVolume ? .accentColor : .secondary
    }
}

struct VolumeRow: View {
    let volume: VolumeInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: volume.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(volume.iconColor)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(volume.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 16) {
                        Label(volume.formattedUsedSpace, systemImage: "chart.pie.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let capacity = volume.formattedCapacity {
                            Label(capacity, systemImage: "internaldrive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if volume.isBootVolume {
                            Label("Boot Volume", systemImage: "circle.fill")
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                Spacer()
                if let usedPercent = volume.usedPercentage {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(usedPercent))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.secondary.opacity(0.2))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(usageColor(for: usedPercent))
                                    .frame(width: geometry.size.width * (usedPercent / 100))
                            }
                        }
                        .frame(width: 80, height: 6)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func usageColor(for percent: Double) -> Color {
        switch percent {
        case 0..<60:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
}

#Preview {
    VolumeSelectionView(
        onSelectVolume: { _ in },
        onChooseFolder: { }
    )
    .frame(width: 640, height: 500)
}


/// A one-click scan of the user's own files, which is the common case for "what filled my
/// disk" — whole-volume scans are mostly system folders that can't be reclaimed anyway.
private struct HomeFolderRow: View {
    let action: () -> Void

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "house.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home Folder")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Label(home.path, systemImage: "person.crop.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.tint.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Shown before a scan starts, so the shortfall is known up front rather than discovered
/// from a banner once the results are already wrong.
private struct FullDiskAccessPrompt: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Copăcel doesn't have Full Disk Access")
                    .font(.callout.bold())
                Text("Scans will skip folders macOS protects, so totals will come up short.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open Settings…") { FullDiskAccessSettings.open() }
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
