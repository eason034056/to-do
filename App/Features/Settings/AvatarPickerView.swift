import SwiftUI
import PhotosUI

struct AvatarPickerView: View {
    @Binding var avatarImage: UIImage?

    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: 16) {
            avatarPreview

            VStack(alignment: .leading, spacing: 6) {
                Text("Your Photo")
                    .font(.headline)
                    .fontDesign(.rounded)

                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Text(avatarImage == nil ? "Choose Photo" : "Change Photo")
                        .font(.callout)
                        .foregroundStyle(CoupleTheme.accent)
                }
                .disabled(isProcessing)

                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(CoupleTheme.urgent)
                }
            }

            Spacer()

            if avatarImage != nil {
                Button("Remove", systemImage: "trash", role: .destructive, action: removePhoto)
                    .font(.callout)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(CoupleTheme.urgent)
            }
        }
        .onChange(of: selectedItem) {
            guard let item = selectedItem else { return }
            processSelectedPhoto(item)
        }
    }

    private var avatarPreview: some View {
        Group {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(CoupleTheme.youColor.opacity(0.1))
                        .frame(width: 64, height: 64)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(CoupleTheme.youColor.opacity(0.4))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func removePhoto() {
        withAnimation {
            avatarImage = nil
            selectedItem = nil
        }
    }

    private func processSelectedPhoto(_ item: PhotosPickerItem) {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let sourceImage = UIImage(data: data) else {
                    errorMessage = "Could not load the selected image."
                    isProcessing = false
                    return
                }

                let processed = try await AvatarProcessor.processAvatar(from: sourceImage)

                withAnimation {
                    avatarImage = processed
                }
                isProcessing = false
            } catch {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }
}
