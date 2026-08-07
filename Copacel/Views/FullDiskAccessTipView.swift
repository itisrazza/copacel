import AppKit
import SwiftUI

struct FullDiskAccessTipView: View {
    var deniedCount: Int
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Some folders were skipped")
                    .bold()
                Text("\(deniedCount) folder\(deniedCount == 1 ? "" : "s") couldn't be read (\(deniedCount == 1 ? "it's" : "they're") likely protected by macOS). Grant Copăcel Full Disk Access to see everything.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            Spacer()

            Button("Open Settings…") { openPrivacySettings() }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.orange.opacity(0.12))
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
