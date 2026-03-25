import SwiftUI
import CoupleTodoCore

struct OfflineBannerView: View {
    @ObservedObject var syncTracker: SyncStatusTracker
    let connectivity: ConnectivityStatus
    let onRetry: () -> Void

    var body: some View {
        if shouldShowBanner {
            HStack(spacing: 8) {
                Image(systemName: bannerIcon)
                    .font(.subheadline)
                Text(bannerMessage)
                    .font(.subheadline)
                Spacer()
                if syncTracker.status == .syncFailed {
                    Button("Retry") {
                        onRetry()
                    }
                    .font(.subheadline.bold())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(bannerColor.opacity(0.15))
            .foregroundColor(bannerColor)
        }
    }

    private var shouldShowBanner: Bool {
        connectivity == .offline || syncTracker.shouldDisplayOfflineBanner
    }

    private var bannerIcon: String {
        switch connectivity {
        case .offline:
            return "wifi.slash"
        default:
            return "exclamationmark.arrow.triangle.2.circlepath"
        }
    }

    private var bannerMessage: String {
        if connectivity == .offline {
            return "You're offline. Changes will sync when connection returns."
        }
        if syncTracker.status == .syncFailed {
            return "Sync failed. Tap Retry."
        }
        return "Syncing..."
    }

    private var bannerColor: Color {
        connectivity == .offline ? .orange : .red
    }
}
