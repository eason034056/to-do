import SwiftUI
import CoupleTodoCore

struct PlanningView: View {
    @ObservedObject var coordinator: AppCoordinator
    let dateKey: String
    @State private var taskEditorState: TaskEditorSheetState?
    @State private var showSubmitCelebration = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
                header
                requiredSection
                optionalSection
                submitPanel
            }
            .padding(.horizontal, CoupleTheme.screenHorizontalPadding)
            .padding(.vertical, 16)
        }
        .navigationTitle("Plan Tomorrow")
        .task {
            await coordinator.refreshPlanningDraft()
        }
        .sheet(item: $taskEditorState) { state in
            NavigationStack {
                TaskEditorView(state: state) { draft, task, dateKey, localTimezone in
                    if let task {
                        coordinator.updatePlanningTaskOptimistically(task.id, draft: draft)
                        Task {
                            await coordinator.saveTaskDraft(
                                draft,
                                existingTask: task,
                                dateKey: dateKey,
                                localTimezone: localTimezone
                            )
                        }
                        return true
                    }

                    guard let optimistic = coordinator.buildOptimisticPlanningTask(
                        title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                        bucket: draft.bucket,
                        priority: draft.priority,
                        dateKey: dateKey
                    ) else {
                        return false
                    }
                    coordinator.insertPlanningTaskOptimistically(optimistic)

                    Task { await coordinator.savePlanningTaskInBackground(optimistic) }
                    return true
                }
            }
            .presentationDetents([.medium, .large])
        }
        .overlay {
            CelebrationOverlay(isActive: $showSubmitCelebration)
        }
    }

    private var header: some View {
        let partnerSubmitted = coordinator.dashboardSnapshot?.partnerSubmittedNextPlan == true
        let emphasis = PlanningPresenter.headerEmphasis(noRequiredConfirmed: coordinator.noRequiredTasksConfirmed)
        let requiredCount = coordinator.planningDraftTasks.filter { $0.bucket == .required && $0.deleted == false }.count
        let optionalCount = coordinator.planningDraftTasks.filter { $0.bucket == .optional && $0.deleted == false }.count

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
                Text("Planning for \(dateKey)")
                    .font(.title2.bold())
                    .fontDesign(.rounded)

                Text("Set up tomorrow's tasks before the cutoff.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(PlanningPresenter.progressText(requiredCount: requiredCount, optionalCount: optionalCount))
                    .font(.callout.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(CoupleTheme.accent)
                    .contentTransition(.numericText())

                HStack(spacing: 10) {
                    StatusPill(
                        text: partnerSubmitted ? "Partner ready" : "Partner drafting",
                        emphasis: partnerSubmitted ? .success : .active
                    )

                    if let snapshot = coordinator.dashboardSnapshot {
                        CountdownBubble(
                            minutes: snapshot.selfPlanningCountdownMinutes,
                            label: "to cutoff"
                        )
                    }
                }
            }
            .padding(CoupleTheme.cardPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoupleGradients.heroGradient)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: CoupleTheme.heroCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: CoupleTheme.heroCornerRadius)
                .strokeBorder(CoupleGradients.cardBorderGradient, lineWidth: 0.5)
        }
        .shadow(
            color: CoupleTheme.cardShadowColor,
            radius: CoupleTheme.cardShadowRadius,
            y: CoupleTheme.cardShadowY
        )
    }

    private var requiredSection: some View {
        let tasks = coordinator.planningDraftTasks.filter { $0.bucket == .required && $0.deleted == false }

        return VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            HStack {
                Text("Required")
                    .font(.sectionTitle)
                    .fontDesign(.rounded)
                Text("\(tasks.count)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer()
                Button("Add", systemImage: "plus") {
                    if let timezone = coordinator.dashboardSnapshot?.user.currentTimezone {
                        taskEditorState = .create(dateKey: dateKey, localTimezone: timezone, bucket: .required)
                    }
                }
                .font(.callout.bold())
                .foregroundStyle(CoupleTheme.active)
            }

            if tasks.isEmpty {
                ContentUnavailableView {
                    Label("No required tasks yet", systemImage: "tray.and.arrow.down")
                } description: {
                    Text("Add required tasks for tomorrow")
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                ForEach(tasks) { task in
                    planningTaskRow(task)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .trailing))
                        ))
                }
            }

            QuickAddRow(placeholder: "Add a required task...", defaultBucket: .required) { title in
                quickAddPlanningTask(title: title, bucket: .required)
            }
        }
        .animation(CoupleAnimations.taskInsertAnimation(reduceMotion), value: tasks.map(\.id))
    }

    private var optionalSection: some View {
        let tasks = coordinator.planningDraftTasks.filter { $0.bucket == .optional && $0.deleted == false }

        return VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            HStack {
                Text("Optional")
                    .font(.sectionTitle)
                    .fontDesign(.rounded)
                Text("\(tasks.count)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer()
                Button("Add", systemImage: "plus") {
                    if let timezone = coordinator.dashboardSnapshot?.user.currentTimezone {
                        taskEditorState = .create(dateKey: dateKey, localTimezone: timezone, bucket: .optional)
                    }
                }
                .font(.callout.bold())
                .foregroundStyle(CoupleTheme.active)
            }

            Button("Carry Over From Today", systemImage: "arrow.uturn.forward") {
                Task { await coordinator.carryOverOptionalTasks() }
            }
            .buttonStyle(SecondaryButtonStyle(.calm))

            if tasks.isEmpty == false {
                ForEach(tasks) { task in
                    planningTaskRow(task)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .trailing))
                        ))
                }
            }

            QuickAddRow(placeholder: "Add an optional task...", defaultBucket: .optional) { title in
                quickAddPlanningTask(title: title, bucket: .optional)
            }
        }
        .animation(CoupleAnimations.taskInsertAnimation(reduceMotion), value: tasks.map(\.id))
    }

    private var isPastDeadline: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 10
    }

    private var submitPanel: some View {
        CoupleCard(emphasis: PlanningPresenter.submitButtonEmphasis(isPastDeadline: isPastDeadline) == .calm ? .urgent : .success) {
            DeadlineBanner(
                deadlineHour: 10,
                isSubmitted: coordinator.dashboardSnapshot?.selfSubmittedNextPlan ?? false
            )

            Toggle("No required tasks tomorrow", isOn: $coordinator.noRequiredTasksConfirmed)
                .tint(CoupleTheme.success)

            if isPastDeadline {
                Label("Submission window closed at 10:00 AM", systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(CoupleTheme.urgent)
            }

            Button("Submit Plan") {
                Task {
                    await coordinator.submitPlanningDraft()
                    showSubmitCelebration = true
                }
            }
            .buttonStyle(PulseButtonStyle(isPastDeadline ? .calm : .success))
            .disabled(isPastDeadline)
            .sensoryFeedback(.success, trigger: showSubmitCelebration)
        }
    }

    private func planningTaskRow(_ task: TodoTask) -> some View {
        SwipeToDeleteRow {
            handleDelete(task)
        } content: {
            TaskRow(
                task: task,
                isEditable: false,
                onTap: { taskEditorState = .edit(task) }
            )
        }
        .sensoryFeedback(.warning, trigger: coordinator.planningDraftTasks.count)
    }

    private func handleDelete(_ task: TodoTask) {
        let saved = task
        withAnimation(CoupleAnimations.taskRemoveAnimation(reduceMotion)) {
            coordinator.removePlanningTaskOptimistically(task.id)
        }
        Task {
            let success = await coordinator.deletePlanningTaskInBackground(saved)
            if success == false {
                withAnimation(CoupleAnimations.taskInsertAnimation(reduceMotion)) {
                    coordinator.insertPlanningTaskOptimistically(saved)
                }
            }
        }
    }

    private func quickAddPlanningTask(title: String, bucket: TaskBucket) {
        guard let optimistic = coordinator.buildOptimisticPlanningTask(
            title: title,
            bucket: bucket,
            dateKey: dateKey
        ) else { return }

        coordinator.insertPlanningTaskOptimistically(optimistic)
        Task { await coordinator.savePlanningTaskInBackground(optimistic) }
    }
}
