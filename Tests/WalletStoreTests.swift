import XCTest
@testable import AppleWalletClone

final class WalletStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WalletStoreTests-\(UUID().uuidString)", isDirectory: true)
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

    private func makeCard(title: String = "Тестовая") -> WalletCard {
        WalletCard(
            title: title,
            type: .credit,
            number: "4111111111111111",
            expiry: "12/30",
            holder: "IVAN IVANOV",
            balance: 1000
        )
    }

    func testAddPlacesCardOnTop() {
        let store = WalletStore(directory: tempDirectory)

        store.add(makeCard(title: "Первая"))
        store.add(makeCard(title: "Вторая"))

        XCTAssertEqual(store.cards.count, 2)
        XCTAssertEqual(store.cards.first?.title, "Вторая")
        XCTAssertEqual(store.cards.first?.sortOrder, 0)
        XCTAssertEqual(store.cards.last?.title, "Первая")
        XCTAssertEqual(store.cards.last?.sortOrder, 1)
    }

    func testDeleteRemovesCardAndReindexes() {
        let store = WalletStore(directory: tempDirectory)
        let first = makeCard(title: "Первая")
        let second = makeCard(title: "Вторая")

        store.add(first)
        store.add(second)
        store.delete(id: second.id)

        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards.first?.id, first.id)
        XCTAssertEqual(store.cards.first?.sortOrder, 0)
    }

    func testPersistenceRoundTrip() {
        let store = WalletStore(directory: tempDirectory)
        let card = makeCard(title: "Сохранённая")
        store.add(card)

        let reloaded = WalletStore(directory: tempDirectory)

        XCTAssertEqual(reloaded.cards.count, 1)
        XCTAssertEqual(reloaded.cards.first?.id, card.id)
        XCTAssertEqual(reloaded.cards.first?.title, "Сохранённая")
        XCTAssertEqual(reloaded.cards.first?.number, "4111111111111111")
    }

    func testCorruptFileYieldsEmptyWalletInsteadOfCrash() throws {
        let url = tempDirectory.appendingPathComponent("wallet.json")
        try Data("definitely not json".utf8).write(to: url)

        let store = WalletStore(directory: tempDirectory)

        XCTAssertTrue(store.cards.isEmpty)
    }

    func testMissingFileYieldsEmptyWallet() {
        let store = WalletStore(directory: tempDirectory)
        XCTAssertTrue(store.cards.isEmpty)
    }

    func testRecordPaymentAddsTransactionAndMovesCardToTop() {
        let store = WalletStore(directory: tempDirectory)
        let first = makeCard(title: "Первая")
        let second = makeCard(title: "Вторая")
        store.add(first)
        store.add(second)

        let transaction = store.recordPayment(
            cardID: first.id,
            merchant: "DEMO STORE",
            amount: 1000
        )

        XCTAssertNotNil(transaction)
        XCTAssertEqual(store.cards.first?.id, first.id)
        XCTAssertEqual(store.cards.first?.transactions.count, 1)
        XCTAssertEqual(store.cards.first?.transactions.first?.merchant, "DEMO STORE")
        XCTAssertEqual(store.cards.first?.transactions.first?.amount, 1000)
        XCTAssertNotNil(store.cards.first?.lastUsedAt)
        XCTAssertEqual(store.cards.first?.sortOrder, 0)
    }

    func testTouchUpdatesSortOrderAndLastUsed() {
        let store = WalletStore(directory: tempDirectory)
        let first = makeCard(title: "Первая")
        let second = makeCard(title: "Вторая")
        store.add(first)
        store.add(second)
        XCTAssertNil(store.card(id: first.id)?.lastUsedAt)

        store.touch(cardID: first.id)

        XCTAssertEqual(store.cards.first?.id, first.id)
        XCTAssertNotNil(store.card(id: first.id)?.lastUsedAt)
        XCTAssertEqual(store.cards.map(\.sortOrder), [0, 1])
    }

    func testUpdateKeepsPosition() {
        let store = WalletStore(directory: tempDirectory)
        let first = makeCard(title: "Первая")
        let second = makeCard(title: "Вторая")
        store.add(first)
        store.add(second)

        var edited = first
        edited.title = "Изменённая"
        store.update(edited)

        XCTAssertEqual(store.cards.count, 2)
        XCTAssertEqual(store.cards.last?.title, "Изменённая")
        XCTAssertEqual(store.cards.last?.id, first.id)
    }

    func testCardMaskShowsLastFourDigits() {
        let card = makeCard()
        XCTAssertEqual(card.maskedNumber, "•••• 1111")
        XCTAssertEqual(card.digits.count, 16)
    }
}
