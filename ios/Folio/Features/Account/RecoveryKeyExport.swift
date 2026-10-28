import FolioCrypto
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Copy, save and print for the recovery key (SPEC §6.13).
enum RecoveryKeyExport {
    nonisolated static func text(_ key: RecoveryKey) -> String {
        """
        Folio Recovery Key

        \(key.displayString)

        This key is the only way to read your diary on a new device if your iPhone is lost.
        Keep it somewhere safe and private. Soul Archive Ltd can't recover it for you.
        """
    }

    /// The clipboard copy stays on this device (no Universal Clipboard) and expires in
    /// 2 minutes, so the key doesn't linger where other apps can read it.
    static func copy(_ key: RecoveryKey) {
        UIPasteboard.general.setItems([[UTType.plainText.identifier: key.displayString]],
                                      options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(120)])
    }

    static func print(_ key: RecoveryKey) {
        let info = UIPrintInfo.printInfo()
        info.outputType = .grayscale
        info.jobName = "Folio Recovery Key"
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        let formatter = UISimpleTextPrintFormatter(text: text(key))
        formatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        formatter.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        controller.printFormatter = formatter
        controller.present(animated: true)
    }
}

/// "Save to Files": a `.txt` named "Folio Recovery Key".
struct RecoveryKeyDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]
    let text: String

    init(key: RecoveryKey) {
        text = RecoveryKeyExport.text(key)
    }

    init(configuration: ReadConfiguration) throws {
        text = configuration.file.regularFileContents.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
