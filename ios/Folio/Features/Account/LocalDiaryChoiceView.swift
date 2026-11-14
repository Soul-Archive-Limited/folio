import SwiftUI

/// Batch O: shown after signing in when this iPhone still holds pages from a *different* Folio
/// account (signed out here earlier). Nothing syncs until the person chooses, so one person's
/// diary can never slip into someone else's account.
struct LocalDiaryChoiceView: View {
    let onCancel: () -> Void

    @Environment(AccountModel.self) private var account
    @Environment(DiaryStore.self) private var store
    @State private var confirmsRemove = false

    var body: some View {
        AccountStepLayout(systemImage: "person.2.slash",
                          title: "Pages from another account",
                          subtitle: "This iPhone still has pages from a different Folio account that was signed out here. They won't be added to this account unless you say so.") {
            Text("If they're yours, add them. If they belong to someone else, remove them from this iPhone — they stay safe in their own account.")
                .folioFont(.callout)
                .foregroundStyle(.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            Button {
                account.addLocalDiaryToAccount()
            } label: {
                Text("Add them to this account").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.accentStrong)
            .accessibilityIdentifier("localDiary.add")
            Button(role: .destructive) {
                confirmsRemove = true
            } label: {
                Text("Remove them from this iPhone").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("localDiary.remove")
            Button("Cancel", action: onCancel)
                .foregroundStyle(.accentText)
                .frame(minHeight: Spacing.minHitTarget)
        }
        .onAppear {
            // Nothing left on the iPhone (or it was removed elsewhere): nothing to decide.
            if store.isEmpty { account.addLocalDiaryToAccount() }
        }
        .confirmationDialog("Remove these pages from this iPhone?", isPresented: $confirmsRemove, titleVisibility: .visible) {
            Button("Remove from this iPhone", role: .destructive) { account.removeLocalDiary(store: store) }
        } message: {
            Text("Changes made on this iPhone after that account signed out aren't in that account and will be lost.")
        }
    }
}
