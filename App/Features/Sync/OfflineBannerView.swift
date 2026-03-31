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
                    .font(.callout)
                Text(bannerMessage)
                    .font(.callout)
                Spacer()
                if syncTracker.status == .syncFailed {
                    Button("Retry", action: onRetry)
                        .font(.callout.bold())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(bannerColor.opacity(0.12))
            .foregroundStyle(bannerColor)
            .clipShape(.rect(cornerRadius: 12))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var shouldShowBanner: Bool {
        connectivity == .offline || syncTracker.shouldDisplayOfflineBanner
    }

    private var bannerIcon: String {
        switch connectivity {
        case .offline: "wifi.slash"
        default: "exclamationmark.arrow.triangle.2.circlepath"
        }
    }

    private var bannerMessage: String {
        if connectivity == .offline {
            return "You're offline"
        }
        if syncTracker.status == .syncFailed {
            return "Sync failed"
        }
        return "Syncing..."
    }

    private var bannerColor: Color {
        connectivity == .offline ? CoupleTheme.warning : CoupleTheme.urgent
    }
}
