import FolioCrypto
import Foundation
import Testing
import UIKit
@testable import Folio

@Suite("Device names, labels and the one-request photo upload (Batch F)")
struct BatchFDeviceTests {
    @Test("Model identifiers map to marketing names; unknown ones fall back")
    func modelNames() {
        #expect(DeviceInfo.modelName(identifier: "iPhone16,1", fallback: "iPhone") == "iPhone 15 Pro")
        #expect(DeviceInfo.modelName(identifier: "iPhone18,1", fallback: "iPhone") == "iPhone 17 Pro")
        #expect(DeviceInfo.modelName(identifier: "iPhone99,9", fallback: "iPhone") == "iPhone")
    }

    @Test("This device's name has the model and the OS")
    @MainActor func name() {
        let name = DeviceInfo.name
        #expect(name.contains(" · "))
        #expect(name.contains(UIDevice.current.systemVersion))
        #expect(name.count <= 64)
    }

    @Test("A photo body is three big-endian lengths, then thumb, display and full")
    func photoBody() {
        let body = APIClient.photoBody(thumb: Data([1, 1]), display: Data([2, 2, 2]), full: Data([3]))
        #expect(body.count == 12 + 6)
        #expect(Array(body.prefix(12)) == [0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 1])
        #expect(Array(body.dropFirst(12)) == [1, 1, 2, 2, 2, 3])
    }

    @Test("A device label seals to its session id and type, and opens only with them")
    func label() throws {
        let key = DataKey.generate()
        let userID = UUID()
        let sessionID = UUID()
        let sealed = try RecordCipher.seal(Data("Kitchen iPad".utf8), recordID: sessionID, type: .deviceLabel, userID: userID, using: key)
        let opened = try RecordCipher.open(sealed, recordID: sessionID, type: .deviceLabel, userID: userID, using: key)
        #expect(String(data: opened, encoding: .utf8) == "Kitchen iPad")
        #expect(throws: FolioCryptoError.self) {
            try RecordCipher.open(sealed, recordID: UUID(), type: .deviceLabel, userID: userID, using: key)
        }
    }
}

@Suite("Photos sync as JPEG (Batch F)")
struct PhotoSyncCopyTests {
    @Test("A HEIC rendition goes up as JPEG; a JPEG passes through")
    func syncCopy() async throws {
        let processed = try await PhotoProcessor().process(Self.samplePNG())
        #expect(PhotoProcessor.isHEIF(processed.imageData))
        let full = await PhotoProcessor().syncCopy(of: processed.imageData, quality: 0.82)
        #expect(Array(full.prefix(3)) == [0xFF, 0xD8, 0xFF])
        #expect(await PhotoProcessor().syncCopy(of: processed.thumbnailData, quality: 0.82) == processed.thumbnailData)
    }

    static func samplePNG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        return renderer.pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
    }
}
