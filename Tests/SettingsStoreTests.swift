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

    func testDefaultsIncludeCameraFaceScan() {
        let store = SettingsStore(directory: tempDirectory)

        XCTAssertTrue(store.useFaceScan)
        XCTAssertFalse(store.requireFaceID)
        XCTAssertFalse(store.useVolumeButtons)
        XCTAssertEqual(store.merchant, "DEMO STORE")
    }

    func testPersistenceRoundTrip() {
        let store = SettingsStore(directory: tempDirectory)
        store.amount = Decimal(string: "250.50") ?? 0
        store.merchant = "CAFE MIR"
        store.requireFaceID = true
        store.useVolumeButtons = true
        store.useFaceScan = false

        let reloaded = SettingsStore(directory: tempDirectory)

        XCTAssertEqual(reloaded.amount, Decimal(string: "250.50"))
        XCTAssertEqual(reloaded.merchant, "CAFE MIR")
        XCTAssertTrue(reloaded.requireFaceID)
        XCTAssertTrue(reloaded.useVolumeButtons)
        XCTAssertFalse(reloaded.useFaceScan)
    }

    func testLegacyJSONWithoutUseFaceScanKeepsOtherFieldsAndDefaultsCameraScan() throws {
        // Старый settings.json — без новых ключей.
        let legacy = """
        {
          "amount": 1200.00,
          "merchant": "OLD STORE",
          "requireFaceID": true,
          "useVolumeButtons": true
        }
        """
        try Data(legacy.utf8).write(to: tempDirectory.appendingPathComponent("settings.json"))

        let store = SettingsStore(directory: tempDirectory)

        XCTAssertEqual(store.merchant, "OLD STORE")
        XCTAssertTrue(store.requireFaceID)
        XCTAssertTrue(store.useVolumeButtons)
        XCTAssertTrue(store.useFaceScan, "отсутствующий ключ — default true")
        XCTAssertEqual(store.amount, Decimal(string: "1200.00"))
    }

    func testCorruptSettingsFileFallsBackToDefaults() throws {
        try Data("definitely not json".utf8)
            .write(to: tempDirectory.appendingPathComponent("settings.json"))

        let store = SettingsStore(directory: tempDirectory)

        XCTAssertEqual(store.merchant, "DEMO STORE")
        XCTAssertTrue(store.useFaceScan)
    }

    func testCurrentSnapshotIncludesUseFaceScan() {
        let store = SettingsStore(directory: tempDirectory)
        store.useFaceScan = false

        XCTAssertFalse(store.current.useFaceScan)
        XCTAssertTrue(AppSettings().useFaceScan)
    }
}
