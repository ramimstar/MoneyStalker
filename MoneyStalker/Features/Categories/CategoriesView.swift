import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var kind: CategoryKind = .expense
    @State private var editing: Category?
    @State private var showEditor = false
    @State private var error: String?

    var body: some View {
        List {
            Picker("Kind", selection: $kind) {
                ForEach(CategoryKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            ForEach(visible) { category in
                HStack {
                    CategoryIcon(systemName: category.icon, hex: category.colorHex)
                    VStack(alignment: .leading) {
                        Text(category.name)
                        if category.isArchived { Text("Archived").font(.caption).foregroundStyle(Color.moneyStalkerSlate) }
                    }
                }
                .swipeActions {
                    Button("Edit") { editing = category; showEditor = true }.tint(Color.moneyStalkerPrimary)
                    Button(category.isArchived ? "Unarchive" : "Archive") { category.isArchived.toggle(); try? context.save() }
                        .tint(Color.moneyStalkerWarning)
                }
            }
            .onMove(perform: move)
        }
        .navigationTitle("Categories")
        .toolbar {
            EditButton()
            Button { editing = nil; showEditor = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add category")
        }
        .sheet(isPresented: $showEditor) { CategoryEditorView(kind: kind, category: editing) }
        .alert("Category", isPresented: errorShown) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
    }

    private var visible: [Category] { categories.filter { $0.kind == kind && $0.parent == nil } }
    private var errorShown: Binding<Bool> { Binding(get: { error != nil }, set: { if !$0 { error = nil } }) }

    private func move(from source: IndexSet, to destination: Int) {
        var items = visible
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() { item.sortOrder = index }
        try? context.save()
    }
}

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    var kind: CategoryKind
    var category: Category?
    var onSave: ((Category) -> Void)? = nil
    @State private var name = ""
    @State private var icon = "tag"
    @State private var color = "1877F2"
    @State private var parentID: UUID?
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CategoryIcon(systemName: icon, hex: color, size: 44)
                        TextField("Category name", text: $name)
                    }
                }
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 14) {
                        ForEach(MoneyStalkerPalette.colors, id: \.self) { hex in
                            Button { color = hex } label: {
                                Circle()
                                    .fill(Color(moneyStalkerHex: hex))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if color == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Color.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color")
                            .accessibilityAddTraits(color == hex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
                ForEach(MoneyStalkerPalette.groups) { group in
                    Section(group.title) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 14) {
                            ForEach(group.icons, id: \.self) { symbol in
                                Button { icon = symbol } label: {
                                    Image(systemName: symbol)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(icon == symbol ? Color.moneyStalkerOnHero : Color.moneyStalkerSecondary)
                                        .frame(width: 42, height: 42)
                                        .background(icon == symbol ? Color.moneyStalkerPrimary : Color.moneyStalkerBorder.opacity(0.35))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(symbol)
                                .accessibilityAddTraits(icon == symbol ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section {
                    Picker("Parent", selection: $parentID) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(categories.filter { $0.kind == kind && $0.parent == nil && $0.id != category?.id }) { item in
                            Text(item.name).tag(Optional(item.id))
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(Color.moneyStalkerExpense) }
            }
            .navigationTitle(category == nil ? "Add category" : "Edit category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let category {
                    name = category.name
                    icon = category.icon
                    color = category.colorHex
                    parentID = category.parent?.id
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "Enter a name."; return }
        let parent = categories.first { $0.id == parentID }
        let saved: Category
        if let category {
            category.name = trimmed
            category.icon = icon
            category.colorHex = color
            category.parent = parent
            saved = category
        } else {
            let created = Category(name: trimmed, kind: kind, icon: icon, colorHex: color, sortOrder: categories.count, parent: parent)
            context.insert(created)
            saved = created
        }
        do {
            try context.save()
            onSave?(saved)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
