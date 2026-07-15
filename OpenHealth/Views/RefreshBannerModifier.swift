import SwiftUI

// MARK: - Refresh Banner Modifier

struct RefreshBannerModifier: ViewModifier {
    let isRefreshing: Bool
    let lastRefreshed: Date?

    @State private var showCompletion = false
    @State private var completionTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Group {
                    if isRefreshing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Daten werden aktualisiert...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(.regularMaterial)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if showCompletion, let date = lastRefreshed {
                        Text("Zuletzt aktualisiert: \(date.formatted(.dateTime.hour().minute()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(.regularMaterial)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.3), value: isRefreshing)
                .animation(.spring(duration: 0.3), value: showCompletion)
            }
            .onChange(of: isRefreshing) { _, newValue in
                if !newValue && lastRefreshed != nil {
                    showCompletion = true
                    completionTask?.cancel()
                    completionTask = Task {
                        try? await Task.sleep(for: .seconds(3))
                        await MainActor.run { showCompletion = false }
                    }
                }
            }
    }
}

// MARK: - View Extension

extension View {
    func refreshBanner(isRefreshing: Bool, lastRefreshed: Date?) -> some View {
        modifier(RefreshBannerModifier(isRefreshing: isRefreshing, lastRefreshed: lastRefreshed))
    }
}
