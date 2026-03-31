import SwiftUI
import CoupleTodoCore

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmationText = ""

    var body: some View {
        Group {
            if let settingsDraft = coordinator.settingsDraft {
                settingsContent(settingsDraft)
            } else {
                ProgressView("Loading Settings")
            }
        }
        .navigationTitle("Settings")
        .onChange(of: coordinator.settingsDraft) { _, _ in
            scheduleAutoSave()
        }
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await coordinator.saveSettings()
        }
    }

    private func settingsContent(_ initial: AppCoordinator.SettingsDraft) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
                profileSection
                planningWindowSection(initial)
                dailyRecapSection(initial)
                penaltySection(initial)
                weekStartSection(initial)
                notificationSection(initial)
                deviceSection(initial)
                actionsSection
            }
            .padding(.horizontal, CoupleTheme.screenHorizontalPadding)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        SettingsSectionHeader(title: "Profile Photo", icon: "camera.fill") {
            CoupleCard(emphasis: .calm) {
                AvatarPickerView(avatarImage: selfAvatarBinding)
            }
        }
    }

    // MARK: - Planning Window

    private func planningWindowSection(_ initial: AppCoordinator.SettingsDraft) -> some View {
        SettingsSectionHeader(title: "Planning Window", icon: "clock.fill") {
            CoupleCard(emphasis: .calm) {
                SettingsRow(label: "Reminder time") {
                    TextField("HH:mm", text: binding(\.planningReminderTime, fallback: initial.planningReminderTime))
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospacedDigit())
                }

                Divider()

                SettingsRow(label: "Cutoff time") {
                    TextField("HH:mm", text: binding(\.planningCutoffTime, fallback: initial.planningCutoffTime))
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospacedDigit())
                }
            }
        }
    }

    // MARK: - Daily Recap

    private func dailyRecapSection(_ initial: AppCoordinator.SettingsDraft) -> some View {
        SettingsSectionHeader(title: "Daily Recap Timing", icon: "chart.bar.fill") {
            CoupleCard(emphasis: .calm) {
                SettingsRow(label: "Settlement time") {
                    TextField("HH:mm", text: binding(\.dailySettlementTime, fallback: initial.dailySettlementTime))
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospacedDigit())
                }

                Divider()

                Stepper(
                    "Grace minutes: \(coordinator.settingsDraft?.dailySettlementGraceMinutes ?? initial.dailySettlementGraceMinutes)",
                    value: binding(\.dailySettlementGraceMinutes, fallback: initial.dailySettlementGraceMinutes),
                    in: 0...15
                )
                .font(.body)
            }
        }
    }

    // MARK: - Penalty

    private func penaltySection(_ initial: AppCoordinator.SettingsDraft) -> some View {
        SettingsSectionHeader(title: "Penalty Rules", icon: "exclamationmark.triangle.fill") {
            CoupleCard(emphasis: .calm) {
                SettingsRow(label: "Amount") {
                    TextField("0", text: binding(\.penaltyAmount, fallback: initial.penaltyAmount))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .font(.body.monospacedDigit())
                }

                Divider()

                SettingsRow(label: "Currency") {
                    TextField("USD", text: binding(\.currency, fallback: initial.currency))
                        .multilineTextAlignment(.trailing)
                }

                Divider()

                Toggle("Planning miss penalty", isOn: binding(\.planningMissPenaltyEnabled, fallback: initial.planningMissPenaltyEnabled))
                    .tint(CoupleTheme.urgent)
            }
        }
    }

    // MARK: - Week Start

    private func weekStartSection(_ initial: AppCoordinator.SettingsDraft) -> some View {
        SettingsSectionHeader(title: "Week Start", icon: "calendar") {
            CoupleCard(emphasis: .calm) {
                Picker("Starts on", selection: binding(\.weekStartsOn, fallback: initial.weekStartsOn)) {
                    ForEach(WeekStart.allCases, id: \.self) { value in
                        Text(value.rawValue.capitalized).tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Notifications

    private func notificationSection(_ initial: AppCoordinator.SettingsDraft) -> some View {
        SettingsSectionHeader(title: "Notifications", icon: "bell.fill") {
            CoupleCard(emphasis: .calm) {
                SettingsRow(label: "Permission") {
                    StatusPill(
                        text: coordinator.settingsDraft?.notificationPermissionStatus ?? initial.notificationPermissionStatus,
                        emphasis: (coordinator.settingsDraft?.notificationPermissionStatus ?? initial.notificationPermissionStatus) == "Authorized" ? .success : .calm
                    )
                }

                Divider()

                Toggle("Planning reminders", isOn: binding(\.planningReminderEnabled, fallback: initial.planningReminderEnabled))
                    .tint(CoupleTheme.active)

                Divider()

                Toggle("Settlement reminders", isOn: binding(\.settlementReminderEnabled, fallback: initial.settlementReminderEnabled))
                    .tint(CoupleTheme.active)

                Divider()

                Toggle("Time Sensitive", isOn: binding(\.timeSensitiveAllowed, fallback: initial.timeSensitiveAllowed))
                    .tint(CoupleTheme.warning)
            }
        }
    }

    // MARK: - Device

    private func deviceSection(_ initial: AppCoordinator.SettingsDraft) -> some View {
        SettingsSectionHeader(title: "Device", icon: "iphone") {
            CoupleCard(emphasis: .calm) {
                SettingsRow(label: "Timezone") {
                    Text(coordinator.settingsDraft?.deviceTimezone ?? initial.deviceTimezone)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("deviceTimezone")

                Divider()

                SettingsRow(label: "UTC offset") {
                    Text("\(coordinator.settingsDraft?.deviceUtcOffsetMinutes ?? initial.deviceUtcOffsetMinutes) min")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: CoupleTheme.itemSpacing) {
            Button(role: .destructive) {
                coordinator.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(SecondaryButtonStyle(.calm))
            .foregroundStyle(CoupleTheme.urgent)

            Button(role: .destructive) {
                deleteConfirmationText = ""
                showDeleteConfirmation = true
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
            .buttonStyle(SecondaryButtonStyle(.calm))
            .foregroundStyle(CoupleTheme.urgent)
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await coordinator.deleteAccount() }
                }
                .disabled(deleteConfirmationText != "DELETE")
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .disabled(coordinator.isDeletingAccount)
            .overlay {
                if coordinator.isDeletingAccount {
                    ProgressView()
                }
            }
        }
    }

    // MARK: - Bindings

    private var selfAvatarBinding: Binding<UIImage?> {
        Binding(
            get: { coordinator.selfAvatarImage },
            set: { coordinator.saveAvatar($0, forSelf: true) }
        )
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppCoordinator.SettingsDraft, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { coordinator.settingsDraft?[keyPath: keyPath] ?? fallback },
            set: { coordinator.settingsDraft?[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Reusable Settings Components

private struct SettingsSectionHeader<Content: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            Label {
                Text(title)
            } icon: {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(CoupleTheme.accent)
                }
            }
            .font(.callout.bold())
            .fontDesign(.rounded)
            .foregroundStyle(.secondary)

            content
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let label: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            trailing
        }
    }
}
