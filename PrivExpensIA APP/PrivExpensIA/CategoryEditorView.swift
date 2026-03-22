import SwiftUI

// MARK: - Category Editor View (Sprint 14)
// Modal for creating and editing document categories with AI instructions

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    // Existing category for editing (nil = creating new)
    let existingCategory: DocumentCategory?
    let parentCategory: DocumentCategory?
    let onSave: () -> Void

    init(existingCategory: DocumentCategory?, parentCategory: DocumentCategory? = nil, onSave: @escaping () -> Void) {
        self.existingCategory = existingCategory
        self.parentCategory = parentCategory
        self.onSave = onSave
    }

    // Form state
    @State private var name: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColor: String = "#007AFF"
    @State private var classificationPrompt: String = ""
    @State private var summaryPrompt: String = ""
    @State private var selectedParentId: UUID?

    // UI state
    @State private var showingIconPicker = false
    @State private var allCategories: [DocumentCategory] = []

    // Available icons
    private let icons = [
        "folder.fill", "doc.fill", "doc.text.fill", "building.2.fill",
        "person.fill", "person.2.fill", "briefcase.fill", "creditcard.fill",
        "banknote.fill", "house.fill", "car.fill", "heart.fill",
        "cross.case.fill", "stethoscope", "graduationcap.fill", "book.fill",
        "cart.fill", "bag.fill", "gift.fill", "airplane",
        "cloud.fill", "server.rack", "laptopcomputer", "iphone",
        "envelope.fill", "phone.fill", "bubble.left.fill", "star.fill"
    ]

    // Available colors
    private let colors = [
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55",
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#30B0C7", "#5AC8FA", "#64D2FF"
    ]

    var isEditing: Bool {
        existingCategory != nil
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Basic Info Section
                Section {
                    // Name field
                    HStack {
                        Image(systemName: selectedIcon)
                            .foregroundColor(Color(hex: selectedColor))
                            .font(.system(size: 24))
                            .frame(width: 40)

                        TextField("Nom de la catégorie", text: $name)
                            .font(.system(size: 17, weight: .medium))
                    }
                } header: {
                    Text("Nom")
                }

                // MARK: - Appearance Section
                Section {
                    // Icon picker
                    Button(action: { showingIconPicker = true }) {
                        HStack {
                            Text("Icône")
                            Spacer()
                            Image(systemName: selectedIcon)
                                .foregroundColor(Color(hex: selectedColor))
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)

                    // Color picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Couleur")
                            .font(.subheadline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                        LiquidGlassTheme.Haptics.light()
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Apparence")
                }

                // MARK: - Parent Folder Section
                Section {
                    Button(action: { selectedParentId = nil }) {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            Text("Racine (aucun parent)")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedParentId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(LiquidGlassTheme.Colors.accent)
                            }
                        }
                    }

                    ForEach(availableParentCategories, id: \.id) { cat in
                        Button(action: { selectedParentId = cat.id }) {
                            HStack {
                                Image(systemName: cat.icon ?? "folder.fill")
                                    .foregroundColor(Color(hex: cat.colorHex ?? "#007AFF"))
                                Text(categoryPathLabel(for: cat))
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedParentId == cat.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(LiquidGlassTheme.Colors.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Dossier parent")
                }

                // MARK: - Classification Instructions Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Décrivez quels documents doivent être classés dans cette catégorie:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $classificationPrompt)
                            .frame(minHeight: 100)
                            .font(.system(size: 15))
                    }
                } header: {
                    Text("Instructions de classification")
                } footer: {
                    Text("Ex: \"Documents de ma société Infinity Cloud: factures, devis, contrats...\"")
                        .font(.caption2)
                }

                // MARK: - Summary Instructions Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Décrivez comment l'IA doit résumer les documents de cette catégorie:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $summaryPrompt)
                            .frame(minHeight: 80)
                            .font(.system(size: 15))
                    }
                } header: {
                    Text("Instructions de résumé")
                } footer: {
                    Text("Ex: \"Extrait: client, montant HT/TTC, date d'échéance\"")
                        .font(.caption2)
                }

                // MARK: - Delete Button (only when editing)
                if isEditing {
                    Section {
                        Button(role: .destructive, action: deleteCategory) {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Supprimer cette catégorie")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier" : "Nouvelle catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enregistrer") {
                        saveCategory()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                iconPickerSheet
            }
            .onAppear {
                loadExistingData()
            }
        }
    }

    // MARK: - Icon Picker Sheet
    private var iconPickerSheet: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 20) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            showingIconPicker = false
                            LiquidGlassTheme.Haptics.light()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.2) : Color.gray.opacity(0.1))
                                    .frame(width: 56, height: 56)

                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : .primary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choisir une icône")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        showingIconPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Categories available as parent (exclude self and descendants to prevent cycles)
    private var availableParentCategories: [DocumentCategory] {
        guard !allCategories.isEmpty else { return [] }

        if let existing = existingCategory, let existingId = existing.id {
            let descendantIds = CoreDataManager.shared.fetchDescendantCategoryIds(of: existingId)
            return allCategories.filter { cat in
                cat.id != existingId && !descendantIds.contains(cat.id ?? UUID())
            }
        }
        return allCategories
    }

    private func categoryPathLabel(for category: DocumentCategory) -> String {
        let path = CoreDataManager.shared.fetchCategoryPath(for: category)
        return path.map { $0.name ?? "?" }.joined(separator: " > ")
    }

    // MARK: - Actions
    private func loadExistingData() {
        allCategories = CoreDataManager.shared.fetchDocumentCategories()

        if let category = existingCategory {
            name = category.name ?? ""
            selectedIcon = category.icon ?? "folder.fill"
            selectedColor = category.colorHex ?? "#007AFF"
            classificationPrompt = category.classificationPrompt ?? ""
            summaryPrompt = category.summaryPrompt ?? ""
            selectedParentId = category.parentId
        } else {
            selectedParentId = parentCategory?.id
        }
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let category = existingCategory {
            // Update existing
            category.parentId = selectedParentId
            CoreDataManager.shared.updateDocumentCategory(
                category,
                name: trimmedName,
                icon: selectedIcon,
                colorHex: selectedColor,
                classificationPrompt: classificationPrompt.isEmpty ? nil : classificationPrompt,
                summaryPrompt: summaryPrompt.isEmpty ? nil : summaryPrompt
            )
        } else {
            // Create new
            let categories = CoreDataManager.shared.fetchDocumentCategories()
            let maxOrder = categories.map { $0.order }.max() ?? -1

            CoreDataManager.shared.createDocumentCategory(
                name: trimmedName,
                icon: selectedIcon,
                colorHex: selectedColor,
                classificationPrompt: classificationPrompt.isEmpty ? nil : classificationPrompt,
                summaryPrompt: summaryPrompt.isEmpty ? nil : summaryPrompt,
                order: maxOrder + 1,
                parentId: selectedParentId
            )
        }

        LiquidGlassTheme.Haptics.success()
        onSave()
        dismiss()
    }

    private func deleteCategory() {
        guard let category = existingCategory else { return }

        CoreDataManager.shared.deleteDocumentCategory(category)
        LiquidGlassTheme.Haptics.warning()
        onSave()
        dismiss()
    }
}

// MARK: - Categories List View
// Displays all categories with edit/delete/reorder functionality

struct CategoriesListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var categories: [DocumentCategory] = []
    @State private var selectedCategory: DocumentCategory?
    @State private var showingEditor = false
    @State private var showingNewCategory = false

    /// Build a flat list with depth info for indented tree display
    private var treeItems: [(category: DocumentCategory, depth: Int)] {
        var result: [(DocumentCategory, Int)] = []

        func addChildren(parentId: UUID?, depth: Int) {
            let children = categories.filter { $0.parentId == parentId }
                .sorted { ($0.order) < ($1.order) }
            for child in children {
                result.append((child, depth))
                addChildren(parentId: child.id, depth: depth + 1)
            }
        }

        addChildren(parentId: nil, depth: 0)
        return result
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(treeItems, id: \.category.id) { item in
                    categoryRow(item.category, depth: item.depth)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCategory = item.category
                            showingEditor = true
                        }
                }
                .onDelete(perform: deleteFromTree)

                // Add new category button
                Button(action: { showingNewCategory = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Nouvelle catégorie")
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Catégories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCategories()
            }
            .onReceive(NotificationCenter.default.publisher(for: .documentCategoryChanged)) { _ in
                loadCategories()
            }
            .sheet(isPresented: $showingEditor) {
                if let category = selectedCategory {
                    CategoryEditorView(existingCategory: category, onSave: loadCategories)
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                CategoryEditorView(existingCategory: nil, onSave: loadCategories)
            }
        }
    }

    private func categoryRow(_ category: DocumentCategory, depth: Int) -> some View {
        HStack(spacing: 12) {
            // Indentation based on depth
            if depth > 0 {
                Spacer()
                    .frame(width: CGFloat(depth) * 24)
            }

            // Icon with color
            ZStack {
                Circle()
                    .fill(Color(hex: category.colorHex ?? "#007AFF").opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: category.icon ?? "folder.fill")
                    .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
            }

            // Name and instruction preview
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name ?? "Catégorie")
                    .font(.system(size: 16, weight: .medium))

                if let prompt = category.classificationPrompt, !prompt.isEmpty {
                    Text(prompt.prefix(50) + (prompt.count > 50 ? "..." : ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Show child count
            let childCount = categories.filter { $0.parentId == category.id }.count
            if childCount > 0 {
                Text("\(childCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.gray.opacity(0.15)))
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func loadCategories() {
        categories = CoreDataManager.shared.fetchDocumentCategories()

        // Create defaults if empty
        if categories.isEmpty {
            CoreDataManager.shared.ensureDefaultCategoriesExist()
            categories = CoreDataManager.shared.fetchDocumentCategories()
        }
    }

    private func deleteFromTree(at offsets: IndexSet) {
        let items = treeItems
        for index in offsets {
            let category = items[index].category
            CoreDataManager.shared.deleteDocumentCategory(category)
        }
        loadCategories()
    }
}

// Color extension defined in DocumentArchiveView.swift

// MARK: - Preview
#Preview {
    CategoriesListView()
}
