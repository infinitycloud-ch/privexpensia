import SwiftUI
import CoreData
import VisionKit

// MARK: - Document Folder View (Flat list with cascading tag filters)
struct DocumentFolderView: View {
    let category: DocumentCategory? // nil = root (always nil now)
    let onScan: (UUID?) -> Void
    let onPhotoPicker: (UUID?) -> Void
    let onFilePicker: (UUID?) -> Void
    let onMagicDropbox: (UUID?) -> Void
    let onSettings: () -> Void
    let onNewSubfolder: (UUID?) -> Void
    let onSelectDocument: (Document) -> Void
    let onEditDocument: (Document) -> Void

    // All data
    @State private var allCategories: [DocumentCategory] = []
    @State private var allDocuments: [Document] = []
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var refreshId = UUID()
    @State private var searchResults: [DocumentSearchResult] = []
    @ObservedObject private var syncService = DocumentSyncService.shared

    // Cascading tag filter state
    @State private var selectedParentId: UUID? = nil  // nil = "Tous"
    @State private var selectedChildId: UUID? = nil    // nil = all in parent

    // Root categories (parentId == nil)
    private var rootCategories: [DocumentCategory] {
        allCategories.filter { $0.parentId == nil }
            .sorted { $0.order < $1.order }
    }

    // Child categories of selected parent
    private var childCategories: [DocumentCategory] {
        guard let parentId = selectedParentId else { return [] }
        return allCategories.filter { $0.parentId == parentId }
            .sorted { $0.order < $1.order }
    }

    // The active category ID for scan/import operations
    private var activeCategoryId: UUID? {
        selectedChildId ?? selectedParentId
    }

    private var isSearching: Bool {
        !debouncedSearchText.isEmpty
    }

    // Category-filtered documents (before search)
    private var categoryFilteredDocuments: [Document] {
        var result = allDocuments

        // Filter by category hierarchy
        if let childId = selectedChildId {
            let descendantIds = CoreDataManager.shared.fetchDescendantCategoryIds(of: childId)
            let allIds = Set([childId] + descendantIds)
            result = result.filter { doc in
                guard let catId = doc.categoryId else { return false }
                return allIds.contains(catId)
            }
        } else if let parentId = selectedParentId {
            let descendantIds = CoreDataManager.shared.fetchDescendantCategoryIds(of: parentId)
            let allIds = Set([parentId] + descendantIds)
            result = result.filter { doc in
                guard let catId = doc.categoryId else { return false }
                return allIds.contains(catId)
            }
        }

        return result
    }

    // Final filtered documents (search applied)
    private var filteredDocuments: [Document] {
        if isSearching {
            return searchResults.map { $0.document }
        }
        return categoryFilteredDocuments
    }

    var body: some View {
        ZStack {
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    // Cascading tag filters (hide when actively searching)
                    if !isSearching {
                        cascadingTagFilters
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    // Search bar
                    searchBar
                        .padding(.horizontal, 20)

                    // Search results count
                    if isSearching {
                        searchResultsHeader
                            .padding(.horizontal, 20)
                    }

                    // Documents list
                    if isSearching {
                        if !searchResults.isEmpty {
                            searchResultsList
                        } else {
                            searchEmptyState
                        }
                    } else if !filteredDocuments.isEmpty {
                        documentsList
                    } else {
                        emptyState
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: searchText) { _, newValue in
            // Debounce search: 300ms delay
            NSObject.cancelPreviousPerformRequests(withTarget: SearchDebouncer.shared)
            SearchDebouncer.shared.perform(after: 0.3) {
                debouncedSearchText = newValue
                performSearch()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 14) {
                    toolbarActionButton(icon: "camera.fill", color: .blue) {
                        if VNDocumentCameraViewController.isSupported {
                            onScan(activeCategoryId)
                        } else {
                            onPhotoPicker(activeCategoryId)
                        }
                    }
                    toolbarActionButton(icon: "photo.fill", color: .purple) {
                        onPhotoPicker(activeCategoryId)
                    }
                    toolbarActionButton(icon: "doc.fill", color: .orange) {
                        onFilePicker(activeCategoryId)
                    }
                    toolbarActionButton(icon: "wand.and.stars", color: .green) {
                        onMagicDropbox(activeCategoryId)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Sync button
                    if syncService.hasSyncFolder {
                        Button(action: { syncService.syncAllDocuments() }) {
                            if syncService.isSyncingAll {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 16))
                            }
                        }
                        .disabled(syncService.isSyncingAll)
                    }

                    // New category/subfolder
                    Button(action: { onNewSubfolder(activeCategoryId) }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16))
                    }

                    // Categories settings
                    Button(action: onSettings) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16))
                    }
                }
            }
        }
        .onAppear { loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .documentAdded)) { _ in loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .documentCategoryChanged)) { _ in loadData() }
    }

    // MARK: - Cascading Tag Filters
    private var cascadingTagFilters: some View {
        VStack(spacing: 8) {
            // Row 1: Root categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "Tous" tag
                    tagPill(
                        name: "Tous",
                        icon: "doc.on.doc",
                        color: LiquidGlassTheme.Colors.accent,
                        isSelected: selectedParentId == nil,
                        count: allDocuments.count
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedParentId = nil
                            selectedChildId = nil
                        }
                    }

                    // Root category tags
                    ForEach(rootCategories, id: \.id) { cat in
                        let count = CoreDataManager.shared.countDocuments(inCategoryAndDescendants: cat.id!)
                        tagPill(
                            name: cat.name ?? "?",
                            icon: cat.icon ?? "folder.fill",
                            color: Color(hex: cat.colorHex ?? "#007AFF"),
                            isSelected: selectedParentId == cat.id,
                            count: count
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedParentId == cat.id {
                                    // Deselect
                                    selectedParentId = nil
                                    selectedChildId = nil
                                } else {
                                    selectedParentId = cat.id
                                    selectedChildId = nil
                                }
                            }
                        }
                    }
                }
            }

            // Row 2: Child categories (only shown when parent has children)
            if !childCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "All in parent" tag
                        if let parentId = selectedParentId,
                           let parent = allCategories.first(where: { $0.id == parentId }) {
                            tagPill(
                                name: "Tout \(parent.name ?? "")",
                                icon: parent.icon ?? "folder.fill",
                                color: Color(hex: parent.colorHex ?? "#007AFF").opacity(0.7),
                                isSelected: selectedChildId == nil,
                                count: nil
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedChildId = nil
                                }
                            }
                        }

                        // Child tags
                        ForEach(childCategories, id: \.id) { child in
                            let count = CoreDataManager.shared.countDocuments(inCategoryAndDescendants: child.id!)
                            tagPill(
                                name: child.name ?? "?",
                                icon: child.icon ?? "folder.fill",
                                color: Color(hex: child.colorHex ?? "#007AFF"),
                                isSelected: selectedChildId == child.id,
                                count: count
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedChildId == child.id {
                                        selectedChildId = nil
                                    } else {
                                        selectedChildId = child.id
                                    }
                                }
                            }
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Tag Pill Component
    private func tagPill(name: String, icon: String, color: Color, isSelected: Bool, count: Int?, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            LiquidGlassTheme.Haptics.light()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(Color(.secondarySystemBackground)))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Toolbar Action Button (compact, icon-only)
    private func toolbarActionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            LiquidGlassTheme.Haptics.light()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(color.gradient)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(LocalizationManager.shared.localized("search"), text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    debouncedSearchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Search Results Header
    private var searchResultsHeader: some View {
        HStack {
            let count = searchResults.count
            Text("\(count) \(count == 1 ? LocalizationManager.shared.localized("search.result") : LocalizationManager.shared.localized("search.results"))")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            // Show "content search" indicator
            if searchResults.contains(where: { $0.matchedFields.contains(.content) }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 11))
                    Text(LocalizationManager.shared.localized("search.in_content"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(LiquidGlassTheme.Colors.accent)
            }
        }
    }

    // MARK: - Search Results List (with snippets)
    private var searchResultsList: some View {
        LazyVStack(spacing: 6) {
            ForEach(searchResults, id: \.document.id) { result in
                let docCategory = CoreDataManager.shared.fetchDocumentCategory(id: result.document.categoryId ?? UUID())
                VStack(spacing: 0) {
                    DocumentRowView(
                        document: result.document,
                        category: docCategory,
                        onTap: { onSelectDocument(result.document) },
                        onDelete: { deleteDocument(result.document) },
                        onEdit: { onEditDocument(result.document) }
                    )

                    // Snippet + match info below the row
                    if result.snippet != nil || result.matchedFields.contains(.content) {
                        searchSnippetView(result: result, categoryColor: Color(hex: docCategory?.colorHex ?? "#007AFF"))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .id(refreshId)
    }

    // MARK: - Search Snippet View
    private func searchSnippetView(result: DocumentSearchResult, categoryColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Match field badges
            HStack(spacing: 6) {
                ForEach(Array(result.matchedFields).sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { field in
                    matchFieldBadge(field)
                }
                Spacer()
            }

            // Snippet text
            if let snippet = result.snippet {
                Text(snippet)
                    .font(.system(size: 12, design: .default))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(categoryColor.opacity(0.05))
        )
        .padding(.top, -4)
    }

    private func matchFieldBadge(_ field: DocumentSearchResult.MatchField) -> some View {
        let (icon, label, color): (String, String, Color) = {
            switch field {
            case .title:
                return ("textformat", LocalizationManager.shared.localized("search.match.title"), .blue)
            case .summary:
                return ("text.quote", LocalizationManager.shared.localized("search.match.summary"), .purple)
            case .content:
                return ("doc.text", LocalizationManager.shared.localized("search.match.content"), .orange)
            }
        }()

        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Documents List
    private var documentsList: some View {
        LazyVStack(spacing: 6) {
            ForEach(filteredDocuments, id: \.id) { document in
                let docCategory = CoreDataManager.shared.fetchDocumentCategory(id: document.categoryId ?? UUID())
                DocumentRowView(
                    document: document,
                    category: docCategory,
                    onTap: { onSelectDocument(document) },
                    onDelete: { deleteDocument(document) },
                    onEdit: { onEditDocument(document) }
                )
            }
        }
        .padding(.horizontal, 20)
        .id(refreshId)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text(LocalizationManager.shared.localized("document.empty"))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)

            Text(LocalizationManager.shared.localized("document.empty.hint"))
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Search Empty State
    private var searchEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.4))

            Text(LocalizationManager.shared.localized("search.no_results"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            Text(LocalizationManager.shared.localized("search.no_results.hint"))
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Data Methods
    private func loadData() {
        allCategories = CoreDataManager.shared.fetchDocumentCategories()

        // Ensure default categories exist
        if allCategories.isEmpty {
            CoreDataManager.shared.ensureDefaultCategoriesExist()
            allCategories = CoreDataManager.shared.fetchDocumentCategories()
        }

        allDocuments = CoreDataManager.shared.fetchDocuments()
        refreshId = UUID()
    }

    private func deleteDocument(_ document: Document) {
        if let docId = document.id {
            DocumentSyncService.shared.deleteExportedFile(for: docId)
        }
        let context = CoreDataManager.shared.persistentContainer.viewContext
        context.delete(document)
        CoreDataManager.shared.saveContext()
        loadData()
    }

    private func performSearch() {
        guard !debouncedSearchText.isEmpty else {
            searchResults = []
            return
        }
        let documentsToSearch = categoryFilteredDocuments
        searchResults = DocumentSearchService.shared.search(
            query: debouncedSearchText,
            in: documentsToSearch
        )
    }
}

// MARK: - Search Debouncer (lightweight, no Combine dependency)
private class SearchDebouncer: NSObject {
    static let shared = SearchDebouncer()
    private var pendingAction: (() -> Void)?

    func perform(after delay: TimeInterval, action: @escaping () -> Void) {
        pendingAction = action
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(execute), object: nil)
        self.perform(#selector(execute), with: nil, afterDelay: delay)
    }

    @objc private func execute() {
        pendingAction?()
        pendingAction = nil
    }
}
