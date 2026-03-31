import SwiftUI
import CoupleTodoCore

struct PartnerBoardSection: View {
    let snapshot: DashboardSnapshot
    @State private var isExpanded = false

    var body: some View {
        let partnerTasks = snapshot.partnerRequired + snapshot.partnerOptional
        if partnerTasks.isEmpty == false {
            VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
                DisclosureGroup(isExpanded: $isExpanded) {
                    ForEach(partnerTasks) { task in
                        TaskRow(task: task, isEditable: false)
                    }
                } label: {
                    HStack {
                        Label("Partner's Board", systemImage: "person.2.fill")
                            .font(.headline)
                            .fontDesign(.rounded)
                            .foregroundStyle(.primary)

                        Spacer()

                        StatusPill(
                            text: partnerSummary,
                            emphasis: partnerEmphasis
                        )
                    }
                }
                .tint(CoupleTheme.partnerColor)
            }
            .sensoryFeedback(.selection, trigger: isExpanded)
        }
    }

    private var partnerSummary: String {
        let completed = snapshot.partnerRequired.filter { $0.status == .completed }.count
        let total = snapshot.partnerRequired.count
        if total == 0 { return "No tasks" }
        if completed == total { return "All done" }
        return "\(completed)/\(total) done"
    }

    private var partnerEmphasis: CoupleTheme.Emphasis {
        let completed = snapshot.partnerRequired.filter { $0.status == .completed }.count
        let total = snapshot.partnerRequired.count
        if total == 0 || completed == total { return .success }
        return .calm
    }
}
