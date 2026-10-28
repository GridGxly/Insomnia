import IOKit.pwr_mgt
import XCTest
@testable import Insomnia

/// Records every create and release; `failCreate` makes the next creates throw.
final class FakeDisplayAssertions: DisplayAssertionHolding, @unchecked Sendable {
    private let lock = NSLock()
    private var _created: [String] = []
    private var _released: [IOPMAssertionID] = []
    private var _next: IOPMAssertionID = 40
    var failCreate = false

    var created: [String] { lock.withLock { _created } }
    var released: [IOPMAssertionID] { lock.withLock { _released } }

    func create(name: String) throws -> IOPMAssertionID {
        if failCreate { throw ScreenAwakeError(status: kIOReturnNotPermitted) }
        return lock.withLock {
            _created.append(name)
            _next += 1
            return _next
        }
    }

    func release(_ id: IOPMAssertionID) {
        lock.withLock { _released.append(id) }
    }
}

@MainActor
final class ScreenAwakeTests: XCTestCase {
    func testHoldsOnceAndReleasesThatAssertion() {
        let fake = FakeDisplayAssertions()
        let awake = ScreenAwake(assertions: fake)

        awake.set(true)
        awake.set(true)

        XCTAssertTrue(awake.isHeld)
        XCTAssertEqual(fake.created, [ScreenAwake.assertionName], "a repeated on holds one assertion")

        awake.set(false)
        awake.set(false)

        XCTAssertFalse(awake.isHeld)
        XCTAssertEqual(fake.released, [41], "the release names the assertion created, once")
    }

    func testReleaseWithNothingHeldDoesNothing() {
        let fake = FakeDisplayAssertions()
        let awake = ScreenAwake(assertions: fake)

        awake.set(false)

        XCTAssertEqual(fake.created, [])
        XCTAssertEqual(fake.released, [])
    }

    /// A refused create holds nothing and is tried again on the next on.
    func testAFailedCreateHoldsNothingAndTheNextOnRetries() {
        let home = TempHome()
        defer { home.destroy() }
        let fake = FakeDisplayAssertions()
        fake.failCreate = true
        let awake = ScreenAwake(assertions: fake)

        awake.set(true)

        XCTAssertFalse(awake.isHeld)
        let log = (try? String(contentsOf: home.paths.logFile, encoding: .utf8)) ?? ""
        XCTAssertTrue(log.contains("the display can still sleep and lock the screen"), log)

        awake.set(false)
        XCTAssertEqual(fake.released, [], "nothing held, nothing released")

        fake.failCreate = false
        awake.set(true)
        XCTAssertTrue(awake.isHeld)
        XCTAssertEqual(fake.created, [ScreenAwake.assertionName])
    }

    /// Without a session the services hold nothing, whatever the setting.
    func testServicesHoldNothingWithoutASession() {
        let home = TempHome()
        defer { home.destroy() }
        let fake = FakeDisplayAssertions()
        let services = AppServices(
            paths: home.paths,
            notifier: RecordingNotifier(),
            audio: FakeAudioControl(),
            processControl: FakeProcessControl(),
            locationPermission: LocationPermission(authorizationStatus: .notDetermined),
            displayAssertions: fake
        )

        services.syncScreenAwake()

        XCTAssertFalse(services.screenAwakeHeld)
        XCTAssertEqual(fake.created, [])
    }
}
