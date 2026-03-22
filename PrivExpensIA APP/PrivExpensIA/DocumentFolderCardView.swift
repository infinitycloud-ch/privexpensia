import SwiftUI

// MARK: - Document Folder Card View (for subcategory grid)
struct DocumentFolderCardView: View {
    let category: DocumentCategory
    let documentCount: Int

    private var categoryColor: Color {
        Color(hex: category.colorHex ?? "#007AFF")
    }

    private var categoryIcon: String {
        category.icon ?? "folder.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: categoryIcon)
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor)
            }

            // Name
            Text(category.name ?? "Folder")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Document count
            Text("\(documentCount) \(documentCount == 1 ? "doc" : "docs")")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}
