import Flutter
import UIKit
import XCTest

@testable import quick_controls

/// Channel answers that need no App Group, so they run on any simulator.
class RunnerTests: XCTestCase {

  private func reply(to method: String, arguments: Any? = nil) -> Any? {
    let plugin = QuickControlsPlugin()
    let call = FlutterMethodCall(methodName: method, arguments: arguments)
    let answered = expectation(description: "\(method) replies")
    var answer: Any?
    plugin.handle(call) { result in
      answer = result
      answered.fulfill()
    }
    waitForExpectations(timeout: 1)
    return answer
  }

  func testIsSupportedRepliesABool() {
    let answer = reply(to: "isSupported")
    XCTAssertNotNil(answer as? Bool)
  }

  func testDrainBeforeInitializeRepliesNotInitialized() {
    let answer = reply(to: "drainPendingEvents")
    XCTAssertEqual((answer as? FlutterError)?.code, "not_initialized")
  }

  func testRequestAddTileIsUnsupported() {
    let answer = reply(to: "requestAddTile", arguments: ["id": "rows"])
    XCTAssertEqual(answer as? String, "unsupported")
  }
}
