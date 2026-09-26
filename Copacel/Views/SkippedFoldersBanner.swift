import CopacelCore
import SwiftUI

/// Reports the directories a scan couldn't read, and on request lists them.
///
/// The summary distinguishes the two causes, because they have different remedies: pointing
/// someone at Full Disk Access for a root-owned folder just wastes their time.
struct SkippedFoldersBanner: View {
    var skipped: SkippedDirectories
    var onDismiss: () -> Void

    @State private var isShowingPaths = false

    private var unresolvableCount: Int { skipped.total - skipped.resolvableByFullDiskAccess }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
            if isShowingPaths {
                Divider()
                pathList
            }
        }
        .background(.orange.opacity(0.12))
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                // Spelled out rather than using `^[...](inflect: true)`, which needs a
                // string catalog this app doesn't have and renders as literal markup without one.
                Text("\(skipped.total) folder\(skipped.total == 1 ? "" : "s") couldn't be read")
                    .bold()
                Text(explanation)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            Spacer()

            Button(isShowingPaths ? "Hide Folders" : "Show Folders") {
                withAnimation(.easeInOut(duration: 0.15)) { isShowingPaths.toggle() }
            }

            if skipped.resolvableByFullDiskAccess > 0 {
                Button("Open Settings…") { FullDiskAccessSettings.open() }
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(10)
    }

    private var explanation: String {
        if skipped.resolvableByFullDiskAccess == 0 {
            return "You don't have permission to read them. Full Disk Access won't change that."
        }
        if unresolvableCount == 0 {
            return "Granting Copăcel Full Disk Access will include them in the scan."
        }
        return """
            Full Disk Access would reveal \(skipped.resolvableByFullDiskAccess); \
            the other \(unresolvableCount) need permissions you don't have.
            """
    }

    /// Accounts for what the list doesn't show: entries beyond the retained sample, and the
    /// routine system folders deliberately kept out of the headline.
    private var footnote: String? {
        var parts: [String] = []
        if skipped.exceedsSample {
            parts.append("\(skipped.total - skipped.sample.count) more not listed")
        }
        if skipped.routine > 0 {
            parts.append("\(skipped.routine) system folder\(skipped.routine == 1 ? "" : "s") skipped as routine")
        }
        return parts.isEmpty ? nil : "…\(parts.joined(separator: ", "))"
    }

    private var pathList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(skipped.sample) { entry in
                        SkippedFolderRow(entry: entry)
                    }
                }
            }
            .frame(maxHeight: 180)

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
        }
    }
}

private struct SkippedFolderRow: View {
    var entry: SkippedDirectories.Entry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.failure.isResolvedByFullDiskAccess ? "lock.fill" : "nosign")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 12)

            Text(entry.url.path)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            Text(entry.failure.isResolvedByFullDiskAccess ? "Privacy-protected" : "No permission")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .help(entry.failure.localizedDescription)
    }
}
