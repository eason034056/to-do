import SwiftUI

struct DashboardView: View {
    private let snapshot = MockDashboardService.makeSnapshot()

    var body: some View {
        NavigationStack {
            List {
                Section("Date Context") {
                    Text(snapshot.selfDateLabel)
                    Text(snapshot.partnerDateLabel)
                }

                Section("Your Required Tasks") {
                    ForEach(snapshot.selfRequired) { task in
                        Label(task.title, systemImage: "checklist")
                    }
                }

                Section("Partner Required Tasks") {
                    ForEach(snapshot.partnerRequired) { task in
                        Label(task.title, systemImage: "person.2")
                    }
                }

                Section("Latest Settlement") {
                    Text(snapshot.latestSettlement.isPass ? "今日達標" : "今日未達標")
                    Text("你今日應支付 $\(snapshot.latestSettlement.owesAmount.description)")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Couple To-Do")
        }
    }
}

#Preview {
    DashboardView()
}
