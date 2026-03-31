import SwiftUI

struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var showingDelete = false
    @GestureState private var dragOffset: CGFloat = 0

    private let deleteThreshold: CGFloat = -80
    private let deleteButtonWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteBackground

            content
                .offset(x: currentOffset)
                .gesture(swipeGesture)
        }
        .clipShape(.rect(cornerRadius: 14))
        .animation(.spring(duration: 0.3, bounce: 0.15), value: offset)
    }

    private var currentOffset: CGFloat {
        let combined = offset + dragOffset
        if combined > 0 { return combined * 0.2 }
        return combined
    }

    private var deleteBackground: some View {
        HStack {
            Spacer()
            Button("Delete", systemImage: "trash", action: handleDelete)
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: deleteButtonWidth)
                .frame(maxHeight: .infinity)
                .background(CoupleTheme.urgent)
        }
        .clipShape(.rect(cornerRadius: 14))
        .opacity(currentOffset < -10 ? 1 : 0)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($dragOffset) { value, state, _ in
                if abs(value.translation.width) > abs(value.translation.height) {
                    state = value.translation.width
                }
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                if projected < deleteThreshold || value.translation.width < deleteThreshold {
                    offset = -deleteButtonWidth
                    showingDelete = true
                } else {
                    offset = 0
                    showingDelete = false
                }
            }
    }

    private func handleDelete() {
        offset = 0
        showingDelete = false
        onDelete()
    }
}
