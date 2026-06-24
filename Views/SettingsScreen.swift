import SwiftUI
import StoreKit
import UIKit

struct SettingsScreen: View {
    @ObservedObject var viewModel: CanvasViewModel
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showUpsell = false

    var body: some View {
        NavigationStack {
            Form {
                physicsSection
                proSection
                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Pro Required", isPresented: $showUpsell) {
                Button("Subscribe") { Task { await store.purchase() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Gravity Strength control requires GravityList Pro.")
            }
        }
    }

    // MARK: - Sections

    private var physicsSection: some View {
        Section("Physics") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Gravity Strength")
                    Spacer()
                    if !store.isPro {
                        Image(systemName: "lock.fill").foregroundStyle(.secondary)
                    }
                }
                Slider(
                    value: Binding(
                        get: { viewModel.gravityMultiplier },
                        set: { viewModel.setGravityMultiplier($0) }
                    ),
                    in: 0.2...3.0,
                    step: 0.1
                )
                .disabled(!store.isPro)
                Text(String(format: "×%.1f", viewModel.gravityMultiplier))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !store.isPro {
                Button("Unlock with Pro") { showUpsell = true }
                    .font(.caption)
            }

            Toggle("Show Completed Tasks", isOn: Binding(
                get: { viewModel.showCompletedTasks },
                set: { viewModel.setShowCompleted($0) }
            ))

            Button("Reset Scene") { viewModel.resetScene() }
        }
    }

    private var proSection: some View {
        Section("GravityList Pro") {
            if store.isPro {
                Label("Pro Active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Button("Manage Subscription") {
                    Task { await manageSubscription() }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlock the full simulation:").font(.subheadline)
                    Label("Unlimited subtasks", systemImage: "checkmark")
                    Label("Gravity strength control", systemImage: "checkmark")
                    Label("Future premium features", systemImage: "checkmark")
                }
                .font(.caption)

                Button {
                    Task { await store.purchase() }
                } label: {
                    HStack {
                        Text("Subscribe")
                        Spacer()
                        Text("\(store.priceText) / month").foregroundStyle(.secondary)
                    }
                }
                .disabled(store.product == nil)
            }

            Button("Restore Purchases") {
                Task { await store.restore() }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func manageSubscription() async {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }
}
