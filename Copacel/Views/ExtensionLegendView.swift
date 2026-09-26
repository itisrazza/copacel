import CopacelCore
import SwiftUI

/// What the legend is highlighting. One selection, expressed at whichever granularity the
/// user is looking at — the treemap resolves either to a set of extensions.
enum LegendHighlight: Equatable, Sendable {
    case fileExtension(String)
    case category(FileCategory)
}

struct ExtensionLegendView: View {
    var stats: [ExtensionStat]
    var categoryStats: [CategoryStat]
    @Binding var highlight: LegendHighlight?

    enum Grouping: String, CaseIterable, Identifiable {
        case kind = "Kind"
        case fileExtension = "Extension"

        var id: Self { self }
    }

    @State private var grouping: Grouping = .kind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Group by", selection: $grouping) {
                ForEach(Grouping.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            header

            switch grouping {
            case .kind:
                List(categoryStats) { stat in
                    CategoryLegendRow(stat: stat, isHighlighted: highlight == .category(stat.category))
                        .contentShape(Rectangle())
                        .onTapGesture { toggle(.category(stat.category)) }
                }
                .listStyle(.inset)
            case .fileExtension:
                List(stats) { stat in
                    ExtensionLegendRow(
                        stat: stat,
                        isHighlighted: highlight == .fileExtension(stat.fileExtension)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(.fileExtension(stat.fileExtension)) }
                }
                .listStyle(.inset)
            }
        }
    }

    /// Clicking the already-highlighted row clears the highlight.
    private func toggle(_ selection: LegendHighlight) {
        highlight = (highlight == selection) ? nil : selection
    }

    private var header: some View {
        HStack {
            Text(grouping == .kind ? "Kind" : "Extension")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Files").frame(width: 56, alignment: .trailing)
            Text("Size").frame(width: 80, alignment: .trailing)
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }
}

private struct CategoryLegendRow: View {
    var stat: CategoryStat
    var isHighlighted: Bool

    /// The extensions actually driving the category's size, so "Disk & VM Images" isn't an
    /// opaque label.
    private var summary: String {
        let shown = stat.extensions.prefix(3).map { $0.isEmpty ? "no extension" : ".\($0)" }
        let remainder = stat.extensions.count - shown.count
        return shown.joined(separator: ", ") + (remainder > 0 ? ", +\(remainder) more" : "")
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: stat.category.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(stat.category.rawValue)
                    .lineLimit(1)
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Text("\(stat.fileCount)")
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
            Text(stat.totalPhysicalSize, format: .byteCount(style: .file))
                .frame(width: 80, alignment: .trailing)
        }
        .font(.system(size: 12))
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            isHighlighted ? Color.accentColor.opacity(0.2) : .clear,
            in: RoundedRectangle(cornerRadius: 4)
        )
    }
}

private struct ExtensionLegendRow: View {
    var stat: ExtensionStat
    var isHighlighted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ColorAssignment.color(forExtension: stat.fileExtension))
                .frame(width: 10, height: 10)
            Text(stat.fileExtension.isEmpty ? "(no extension)" : ".\(stat.fileExtension)")
                .lineLimit(1)
            Spacer()
            Text("\(stat.fileCount)")
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
            Text(stat.totalPhysicalSize, format: .byteCount(style: .file))
                .frame(width: 80, alignment: .trailing)
        }
        .font(.system(size: 12))
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            isHighlighted ? Color.accentColor.opacity(0.2) : .clear,
            in: RoundedRectangle(cornerRadius: 4)
        )
    }
}
