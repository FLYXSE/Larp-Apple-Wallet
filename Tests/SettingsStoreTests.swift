import XCTest
@testable import AppleWalletClone

final class SettingsStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testDefaults() {
        let store = SettingsStore(directory: tempDirectory)

        XCTAssertTrue(store.requireFaceID)
        XCTAssertFalse(store.useVolumeButtons)
        XCTAssertEqual(store.merchant, "DEMO STORE")
        XCTAssertEqual(store.amount, Decimal(string: "1000.00"))
    }

    func testPersistenceRoundTrip() {
        let store = SettingsStore(directory: tempDirectory)
        store.amount = Decimal(string: "250.50") ?? 0
        store.merchant = "CAFE MIR"
        store.requireFaceID = false
        store.useVolumeButtons = true

        let reloaded = SettingsStore(directory: tempDirectory)

        XCTAssertEqual(reloaded.amount, Decimal(string: "250.50"))
        XCTAssertEqual(reloaded.merchant, "CAFE MIR")
        XCTAssertFalse(reloaded.requireFaceID)
        XCTAssertTrue(reloaded.useVolumeButtons)
    }

    func testLegacyJSONKeepsKnownFields() throws {
        let legacy = """
        {
          "amount": 1200.00,
          "merchant": "OLD STORE",
          "requireFaceID": false,
          "useVolumeButtons": true,
          "useFaceScan": true
        }
        """
        try Data(legacy.utf8).write(to: tempDirectory.appendingPathComponent("settings.json"))

        let store = SettingsStore(directory: tempDirectory)

        XCTAssertEqual(store.merchant, "OLD STORE")
        XCTAssertFalse(store.requireFaceID)
        XCTAssertTrue(store.useVolumeButtons)
        XCTAssertEqual(store.amount, Decimal(string: "1200.00"))
    }

    func testCorruptSettingsFileFallsBackToDefaults() throws {
        try Data("definitely not json".utf8)
            .write(to: tempDirectory.appendingPathComponent("settings.json"))

        let store = SettingsStore(directory: tempDirectory)

        XCTAssertEqual(store.merchant, "DEMO STORE")
        XCTAssertTrue(store.requireFaceID)
    }

    func testCurrentSnapshot() {
        let store = SettingsStore(directory: tempDirectory)
        store.requireFaceID = false

        XCTAssertFalse(store.current.requireFaceID)
        XCTAssertTrue(AppSettings().requireFaceID)
    }
}
