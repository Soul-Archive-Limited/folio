import SwiftUI

/// Profile → Devices (SPEC §6.9): every signed-in device and browser, with Sign out on each
/// and "Sign out other devices".
struct DevicesView: View {
    @Environment(AccountModel.self) private var account
    @State private var devices: [AccountAPI.Device]?
    @State private var problem: SignInProblem?
    @State private var confirmsOthers = false
    @State private var renaming: AccountAPI.Device?
    @State private var newName = ""

    var body: some View {
        List {
            if let devices {
                Section {
                    ForEach(devices) { device in
                        Button { startRenaming(device) } label: {
                            DeviceRow(device: device, label: account.label(of: device))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Renames this device")
                        .swipeActions(edge: .leading) {
                            Button("Rename") { startRenaming(device) }.tint(.ember)
                        }
                        .swipeActions {
                            if !device.current {
                                Button("Sign out", role: .destructive) { signOut(device) }
                            }
                        }
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") { startRenaming(device) }
                            if !device.current {
                                Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { signOut(device) }
                            }
                        }
                    }
                } footer: {
                    Text("Tap a device to rename it; the name is encrypted like your diary. Swipe to sign it out — its copy of your diary stays on it until it's signed out there too.")
                }
                .listRowBackground(ProfileRowBackground())
                if devices.count > 1 {
                    Section {
                        Button("Sign out other devices", role: .destructive) { confirmsOthers = true }
                    }
                    .listRowBackground(ProfileRowBackground())
                }
            } else if let problem {
                Text(problem.message).foregroundStyle(.inkSecondary)
                    .listRowBackground(ProfileRowBackground())
            } else {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background { AuraBackground() }
        .navigationTitle("Devices")
        .refreshable { await load() }
        .task { await load() }
        .alert("Rename device", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(renaming?.name ?? "Name", text: $newName)
                .onChange(of: newName) { _, value in
                    if value.count > AccountModel.deviceLabelLimit { newName = String(value.prefix(AccountModel.deviceLabelLimit)) }
                }
            Button("Save") { rename() }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text("Leave it empty to show the model again.")
        }
        .confirmationDialog("Sign out every other device and browser?", isPresented: $confirmsOthers, titleVisibility: .visible) {
            Button("Sign out other devices", role: .destructive) {
                Task {
                    let _: Void? = try? await account.signOutOtherDevices()
                    await load()
                }
            }
        }
    }

    private func load() async {
        do throws(APIError) {
            devices = try await account.devices()
            problem = nil
        } catch {
            problem = error.signInProblem
        }
    }

    private func startRenaming(_ device: AccountAPI.Device) {
        newName = account.label(of: device) ?? ""
        renaming = device
    }

    private func rename() {
        guard let device = renaming else { return }
        renaming = nil
        let name = newName
        Task {
            do throws(APIError) {
                try await account.renameDevice(device.id, to: name)
                await load()
            } catch {
                problem = error.signInProblem
            }
        }
    }

    private func signOut(_ device: AccountAPI.Device) {
        Task {
            let _: Void? = try? await account.signOutDevice(device.id)
            await load()
        }
    }
}
