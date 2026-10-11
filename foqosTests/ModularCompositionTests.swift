import XCTest

@testable import foqos

@MainActor
final class ModularCompositionTests: ModelRegressionTestCase {
  func testOptionalControlsCanStartIntentionalProfileWithoutAdoptingEachOthersSession() throws {
    let profile = BlockedProfiles(
      name: "Family challenges",
      blockingStrategyId: IntentionalAccessBlockingStrategy.id,
      strategyData: try JSONEncoder().encode(IntentionalAccessConfiguration()))
    context.insert(profile)
    try context.save()
    let suite = "composition-tests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let strategy = StrategyManager()
    defer { strategy.stopTimer() }
    let controllers = ["geofence", "activity", "partner"].map {
      ProfileSessionControl(
        context: context, key: $0, defaults: defaults,
        manager: strategy, isAuthorized: { true })
    }
    for controller in controllers { controller.profileID = profile.id }
    for owner in controllers {
      XCTAssertTrue(owner.setActive(true))
      let session = try XCTUnwrap(BlockedProfileSession.mostRecentActiveSession(in: context))
      XCTAssertEqual(SoftUnblockGrantStore.activeSession?.sessionId, session.id)
      for other in controllers where other !== owner {
        XCTAssertFalse(other.setActive(true))
        XCTAssertFalse(other.setActive(false))
      }
      XCTAssertNil(session.endTime)
      XCTAssertTrue(owner.setActive(false))
      XCTAssertNil(SoftUnblockGrantStore.activeSession)
    }
  }
}
