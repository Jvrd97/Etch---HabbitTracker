// [review:need-review] PHASE-01/09-ios-journal
// summary: Journal screen — feed of entries (date, mood, tags, preview), compose sheet with title/text/mood picker/tags, swipe-delete
import SwiftUI

struct JournalView: View {
    @StateObject private var viewModel: JournalViewModel
    @State private var pendingDeletion: JournalEntryDTO?

    init(viewModel: JournalViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Journal")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.beginComposing()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .accessibilityLabel("New journal entry")
                        }
                    }
                }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.isComposing) {
            JournalComposeView(viewModel: viewModel)
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: deletionBinding,
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { entry in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteEntry(id: entry.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This permanently removes the entry.")
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failure(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(message).multilineTextAlignment(.center)
                Button("Retry") { Task { await viewModel.load() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            feed
        }
    }

    @ViewBuilder
    private var feed: some View {
        if viewModel.entries.isEmpty {
            ContentUnavailableView(
                "No entries yet",
                systemImage: "book.closed",
                description: Text("Tap the compose button to write about your day.")
            )
        } else {
            List {
                ForEach(viewModel.entries) { entry in
                    JournalRow(entry: entry)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDeletion = entry
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .refreshable { await viewModel.load() }
        }
    }
}

/// A single feed row: date + mood on top, optional title, a content preview, and tag chips.
struct JournalRow: View {
    let entry: JournalEntryDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.entryDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let mood = entry.mood, let label = JournalMood(rawValue: mood)?.label {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let title = entry.title, !title.isEmpty {
                Text(title).font(.headline)
            }
            Text(entry.content)
                .font(.body)
                .lineLimit(3)
            let tags = JournalTags.parse(entry.tags ?? "")
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Compose sheet for a new entry: title, mood picker, free-text body, and comma tags.
struct JournalComposeView: View {
    @ObservedObject var viewModel: JournalViewModel
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Entry") {
                    TextField("Title (optional)", text: $viewModel.draftTitle)
                    TextField("Date (YYYY-MM-DD)", text: $viewModel.draftDate)
                        .keyboardType(.numbersAndPunctuation)
                }
                Section("Mood") {
                    Picker("Mood", selection: $viewModel.draftMood) {
                        Text("None").tag(String?.none)
                        ForEach(JournalMood.allCases) { mood in
                            Text(mood.label).tag(String?.some(mood.rawValue))
                        }
                    }
                }
                Section("How was your day?") {
                    TextField("Write about your day…", text: $viewModel.draftContent, axis: .vertical)
                        .lineLimit(4...12)
                }
                Section("Tags") {
                    TextField("comma, separated, tags", text: $viewModel.draftTags)
                        .autocorrectionDisabled()
                }
                if let message = viewModel.saveErrorMessage {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancelComposing() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        _ = await viewModel.createEntry()
    }
}
