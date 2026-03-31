import SwiftUI
import CoupleTodoCore

struct TodayView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var showCelebration = false
    @State private var refreshCount = 0

    var body: some View {
        Group {
            if let snapshot = coordinator.dashboardSnapshot {
                todayContent(snapshot)
            } else {
                ProgressView("Loading...")
                    .task {
                        await coordinator.bootstrapIfNeeded()
                    }
            }
        }
        .overlay {
            CelebrationOverlay(isActive: $showCelebration)
        }
        .sensoryFeedback(.success, trigger: showCelebration)
        .sensoryFeedback(.success, trigger: refreshCount)
    }

    private func todayContent(_ snapshot: DashboardSnapshot) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
                OfflineBannerView(
                    syncTracker: coordinator.syncTracker,
                    connectivity: coordinator.connectivity
                ) {
                    Task { await coordinator.retrySyncManually() }
                }

                TodayHeroSection(
                    snapshot: snapshot,
                    selfAvatar: coordinator.selfAvatarImage,
                    partnerAvatar: coordinator.partnerAvatarImage
                )

                TaskSectionView(
                    kind: .required,
                    tasks: snapshot.selfRequired,
                    coordinator: coordinator,
                    onCelebrationCheck: checkCelebration,
                    onEditTask: { _ in }
                )

                TaskSectionView(
                    kind: .optional,
                    tasks: snapshot.selfOptional,
                    coordinator: coordinator,
                    onCelebrationCheck: checkCelebration,
                    onEditTask: { _ in }
                )

                PartnerBoardSection(snapshot: snapshot)
            }
            .padding(.horizontal, CoupleTheme.screenHorizontalPadding)
            .padding(.bottom, CoupleTheme.screenBottomPadding)
        }
        .refreshable {
            await coordinator.refreshDashboard()
            await coordinator.refreshPlanningDraft()
            refreshCount += 1
        }
        .navigationTitle("Today's Todo")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                StatusPill(text: snapshot.selfContext.dateKey, emphasis: .calm)
            }
        }
    }

    private func checkCelebration() {
        guard let snapshot = coordinator.dashboardSnapshot else { return }
        let allRequiredDone = snapshot.selfRequired.allSatisfy { $0.status == .completed }
        if allRequiredDone && snapshot.selfRequired.isEmpty == false {
            showCelebration = true
        }
    }
}
