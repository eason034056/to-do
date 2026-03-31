import SwiftUI
import CoupleTodoCore

struct TaskEditorDraft: Equatable {
    var title: String
    var notes: String
    var bucket: TaskBucket
    var priority: TaskPriority

    init(
        title: String = "",
        notes: String = "",
        bucket: TaskBucket = .required,
        priority: TaskPriority = .p1
    ) {
        self.title = title
        self.notes = notes
        self.bucket = bucket
        self.priority = priority
    }

    init(task: TodoTask) {
        title = task.title
        notes = task.notes ?? ""
        bucket = task.bucket
        priority = task.priority
    }
}

struct TaskEditorSheetState: Identifiable {
    let id: String
    let title: String
    let dateKey: String
    let localTimezone: String
    let task: TodoTask?
    let defaultBucket: TaskBucket

    static func edit(_ task: TodoTask) -> TaskEditorSheetState {
        TaskEditorSheetState(
            id: "edit_\(task.id)",
            title: "Edit Task",
            dateKey: task.dateKey,
            localTimezone: task.localTimezone,
            task: task,
            defaultBucket: task.bucket
        )
    }

    static func create(dateKey: String, localTimezone: String, bucket: TaskBucket) -> TaskEditorSheetState {
        TaskEditorSheetState(
            id: "create_\(dateKey)_\(bucket.rawValue)",
            title: bucket == .required ? "New Required Task" : "New Optional Task",
            dateKey: dateKey,
            localTimezone: localTimezone,
            task: nil,
            defaultBucket: bucket
        )
    }
}

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let state: TaskEditorSheetState
    let onSave: (TaskEditorDraft, TodoTask?, String, String) async -> Bool

    @State private var draft: TaskEditorDraft
    @State private var isSaving = false
    @FocusState private var titleFocused: Bool

    init(
        state: TaskEditorSheetState,
        onSave: @escaping (TaskEditorDraft, TodoTask?, String, String) async -> Bool
    ) {
        self.state = state
        self.onSave = onSave
        if let task = state.task {
            _draft = State(initialValue: TaskEditorDraft(task: task))
        } else {
            _draft = State(initialValue: TaskEditorDraft(bucket: state.defaultBucket))
        }
    }

    private var canSave: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && isSaving == false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
                titleCard
                categoryCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .bottom) {
            Button(state.task == nil ? "Add Task" : "Save Changes", action: save)
                .buttonStyle(PulseButtonStyle(canSave ? .active : .calm))
                .disabled(canSave == false)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(state.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }
        }
        .sensoryFeedback(.success, trigger: isSaving)
        .onAppear { titleFocused = state.task == nil }
    }

    private var titleCard: some View {
        CoupleCard(emphasis: .active) {
            TextField("Task title", text: $draft.title)
                .font(.title3.bold())
                .fontDesign(.rounded)
                .focused($titleFocused)
                .submitLabel(.next)

            TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1...4)
        }
    }

    private var categoryCard: some View {
        CoupleCard(emphasis: .calm) {
            Text("Category")
                .font(.callout.bold())
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)

            Picker("Type", selection: $draft.bucket) {
                ForEach(TaskBucket.allCases, id: \.self) { bucket in
                    Text(bucket.rawValue.capitalized).tag(bucket)
                }
            }
            .pickerStyle(.segmented)

            Picker("Priority", selection: $draft.priority) {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Text(priority.rawValue.uppercased()).tag(priority)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func save() {
        Task {
            isSaving = true
            let didSave = await onSave(draft, state.task, state.dateKey, state.localTimezone)
            isSaving = false
            if didSave { dismiss() }
        }
    }
}
