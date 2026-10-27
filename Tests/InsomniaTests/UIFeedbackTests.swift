import AppKit
import SwiftUI
import XCTest
@testable import Insomnia

final class UIFeedbackTests: XCTestCase {
    @MainActor
    func testSoundWaitsForSuccessfulActivationAndCompletedDeactivation() async throws {
        let harness = Harness()
        defer { harness.home.destroy() }
        let manager = harness.makeManager()
        var cues: [SessionSoundCue] = []
        let controller = StatusItemController(manager: manager, status: PlaceholderStatus(), showSettings: {}, playSessionSound: { cues.append($0) })
        let gate = AsyncGate()
        harness.backstop.armGate = gate
        controller.toggleSession()
        await gate.waitUntilStarted()
        XCTAssertTrue(cues.isEmpty)
        controller.toggleSession()
        await gate.open()
        await settle { cues == [.activated] }
        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(cues, [.activated])
        let restoreGate = AsyncGate()
        harness.guardFake.restoreGate = restoreGate
        controller.toggleSession()
        await restoreGate.waitUntilStarted()
        XCTAssertEqual(cues, [.activated], "The stop sound waits until restoration finishes")
        await restoreGate.open()
        await settle { cues.count == 2 }
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(cues, [.activated, .deactivated])
    }

    @MainActor
    func testIncompleteRestorationDoesNotPlayASuccessSound() async {
        let harness = Harness()
        defer { harness.home.destroy() }
        let manager = harness.makeManager()
        var cues: [SessionSoundCue] = []
        let controller = StatusItemController(manager: manager, status: PlaceholderStatus(), showSettings: {}, playSessionSound: { cues.append($0) })
        controller.toggleSession()
        await settle { cues == [.activated] }
        harness.guardFake.throwOn = ["disablesleep 0"]
        controller.toggleSession()
        await settle { manager.lastError != nil }
        XCTAssertTrue(harness.guardFake.sleepDisabled)
        XCTAssertEqual(cues, [.activated])
        harness.guardFake.throwOn = []
        await manager.end(reason: .user)
    }

    @MainActor
    func testFailedStartIsSilent() async {
        let harness = Harness()
        defer { harness.home.destroy() }
        harness.backstop.failArm = true
        let manager = harness.makeManager()
        var cues: [SessionSoundCue] = []
        let controller = StatusItemController(manager: manager, status: PlaceholderStatus(), showSettings: {}, playSessionSound: { cues.append($0) })
        controller.toggleSession()
        await settle { controller.model.phase != .starting }
        XCTAssertFalse(manager.isActive)
        XCTAssertNotNil(manager.lastError)
        XCTAssertTrue(cues.isEmpty)
    }

    @MainActor
    func testBothCuesDecodeAsDistinctShortSoundsWithoutPlayingAudio() throws {
        let start = SessionSoundCue.activated.waveData
        let end = SessionSoundCue.deactivated.waveData
        XCTAssertNotEqual(start, end)
        for data in [start, end] {
            let sound = try XCTUnwrap(NSSound(data: data))
            XCTAssertEqual(sound.duration, 0.14, accuracy: 0.002)
            XCTAssertEqual(Array(data[44..<46]), [0, 0])
            XCTAssertEqual(Array(data.suffix(2)), [0, 0])
        }
    }

    @MainActor
    private func settle(_ complete: @MainActor () -> Bool) async {
        let deadline = Date().addingTimeInterval(2)
        while !complete(), Date() < deadline { try? await Task.sleep(for: .milliseconds(10)) }
    }
}
