import SwiftUI

struct TaskSectionHeaderView: View {
    let title: String
    let count: Int
    var onAdd: (() -> Void)?

    @State private var addTapCount = 0

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .fontDesign(.rounded)

            Text("\(count)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            if let onAdd {
                Button("Add", systemImage: "plus", action: {
                    addTapCount += 1
                    onAdd()
                })
                .font(.callout.bold())
                .foregroundStyle(CoupleTheme.active)
            }
        }
        .sensoryFeedback(.selection, trigger: addTapCount)
    }
}
