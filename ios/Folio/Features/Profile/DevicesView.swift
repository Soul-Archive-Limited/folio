import SwiftUI

/// Profile → Devices (SPEC §6.9): every signed-in device and browser, with Sign out on each
/// and "Sign out other devices".
struct DevicesView: View {
    @Environment(AccountModel.self) private var account
    @State private var devices: [AccountAPI.Device]?
    @State private var problem: SignInProblem?
    @State private var confirmsOthers = false

    var body: some View {
        List {
            if let devices {
                Section {
                    ForEach(devices) { device in
                        DeviceRow(device: device)
                            .swipeActions {
                                if !device.current {
                                    Button("Sign out", role: .destructive) { signOut(device) }
                                }
                            }
                            .contextMenu {
                                if !device.current {
                                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { signOut(device) }
                                }
                            }
                    }
                } footer: {
                    Text("Swipe a device to sign it out. Its copy of your diary stays on it until it's signed out there too.")
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

    private func signOut(_ device: AccountAPI.Device) {
        Task {
            let _: Void? = try? await account.signOutDevice(device.id)
            await load()
        }
    }
}

/// One device: name, "This iPhone" or when it was last seen.
struct DeviceRow: View {
    let device: AccountAPI.Device

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: device.platform == "web" ? "globe" : "iphone")
                .foregroundStyle(.ember)
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).foregroundStyle(.ink)
                Group {
                    if device.current {
                        Text("This device")
                    } else {
                        Text("Last seen \(Date(timeIntervalSince1970: device.lastSeenAt / 1000), format: .relative(presentation: .named))")
                    }
                }
                .folioFont(.caption)
                .foregroundStyle(.inkTertiary)
            }
        }
        .folioFont(.body)
        .frame(minHeight: Spacing.minHitTarget)
        .accessibilityElement(children: .combine)
    }
}
