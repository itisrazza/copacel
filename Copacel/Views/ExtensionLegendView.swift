import CopacelCore
import SwiftUI

struct ExtensionLegendView: View {
    var stats: [ExtensionStat]
    @Binding var selectedExtension: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            List(stats) { stat in
                HStack(spacing: 8) {
                    Circle()
                        .fill(ColorAssignment.color(forExtension: stat.fileExtension))
                        .frame(width: 10, height: 10)
                    Text(stat.fileExtension.isEmpty ? "(no extension)" : ".\(stat.fileExtension)")
                        .lineLimit(1)
                    Spacer()
                    Text("\(stat.fileCount)")
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    Text(stat.totalPhysicalSize, format: .byteCount(style: .file))
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.system(size: 12))
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(
                    selectedExtension == stat.fileExtension ? Color.accentColor.opacity(0.2) : .clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    // Toggle: clicking the already-selected row clears the highlight.
                    selectedExtension = (selectedExtension == stat.fileExtension) ? nil : stat.fileExtension
                }
            }
            .listStyle(.inset)
        }
    }

    private var header: some View {
        HStack {
            Text("Extension").frame(maxWidth: .infinity, alignment: .leading)
            Text("Files").frame(width: 40, alignment: .trailing)
            Text("Size").frame(width: 80, alignment: .trailing)
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
