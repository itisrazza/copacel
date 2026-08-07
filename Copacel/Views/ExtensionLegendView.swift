import CopacelCore
import SwiftUI

struct ExtensionLegendView: View {
    var stats: [ExtensionStat]

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
