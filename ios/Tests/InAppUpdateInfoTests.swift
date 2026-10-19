import Foundation
import XCTest

// Compiled together with InAppUpdateInfo.swift by scripts/test_ios.sh.

private func date(_ iso: String) -> Date {
  ISO8601DateFormatter().date(from: iso)!
}

final class CompareVersionsTests: XCTestCase {
  private func compare(_ a: String, _ b: String) -> ComparisonResult {
    InAppUpdateInfo.compareVersions(a, b)
  }

  func testEqualVersions() {
    XCTAssertEqual(compare("1.2.3", "1.2.3"), .orderedSame)
  }

  func testMissingSegmentsCountAsZero() {
    XCTAssertEqual(compare("1.0", "1.0.0"), .orderedSame)
    XCTAssertEqual(compare("2", "2.0"), .orderedSame)
    XCTAssertEqual(compare("1.0.1", "1.0"), .orderedDescending)
    XCTAssertEqual(compare("1.0", "1.0.1"), .orderedAscending)
  }

  func testComparesNumericallyNotLexically() {
    XCTAssertEqual(compare("1.10", "1.9"), .orderedDescending)
    XCTAssertEqual(compare("1.9", "1.10"), .orderedAscending)
    XCTAssertEqual(compare("10.0", "9.9.9"), .orderedDescending)
  }

  func testEarlierSegmentsWin() {
    XCTAssertEqual(compare("2.0.0", "1.99.99"), .orderedDescending)
    XCTAssertEqual(compare("1.2.9", "1.3.0"), .orderedAscending)
  }

  func testNonNumericSegmentsCountAsZero() {
    XCTAssertEqual(compare("1.0.beta", "1.0"), .orderedSame)
    XCTAssertEqual(compare("", "0"), .orderedSame)
  }

  func testSegmentsCountByTheirLeadingDigits() {
    XCTAssertEqual(compare("1.2b", "1.2"), .orderedSame)
    XCTAssertEqual(compare("1.10rc1", "1.9"), .orderedDescending)
  }
}

final class LookupURLTests: XCTestCase {
  private func query(of url: URL) -> [String: String] {
    var query: [String: String] = [:]
    for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
      query[item.name] = item.value
    }
    return query
  }

  func testLooksUpTheBundleIdInTheRegionalStore() {
    let url = InAppUpdateInfo.lookupURL(
      bundleId: "com.example.app", country: "IN", now: Date(timeIntervalSince1970: 1_700_000_000))
    XCTAssertEqual(url.scheme, "https")
    XCTAssertEqual(url.host, "itunes.apple.com")
    XCTAssertEqual(url.path, "/lookup")
    XCTAssertEqual(query(of: url)["bundleId"], "com.example.app")
    XCTAssertEqual(query(of: url)["country"], "in")
  }

  func testOmitsCountryForTheDefaultStore() {
    let url = InAppUpdateInfo.lookupURL(bundleId: "com.example.app", country: nil, now: Date())
    XCTAssertNil(query(of: url)["country"])
  }

  func testAddsATimestampToBypassApplesCache() {
    let url = InAppUpdateInfo.lookupURL(
      bundleId: "com.example.app", country: nil, now: Date(timeIntervalSince1970: 1_700_000_000))
    XCTAssertEqual(query(of: url)["_"], "1700000000")
  }

  func testEscapesTheBundleId() {
    let url = InAppUpdateInfo.lookupURL(bundleId: "com.example.app&x=1", country: nil, now: Date())
    XCTAssertEqual(query(of: url)["bundleId"], "com.example.app&x=1")
  }
}

final class AppFromLookupDataTests: XCTestCase {
  private func parse(_ json: String) throws -> [String: Any]? {
    try InAppUpdateInfo.app(fromLookupData: Data(json.utf8))
  }

  func testReturnsTheFirstResult() throws {
    let app = try parse(#"{"resultCount":2,"results":[{"version":"2.0"},{"version":"1.0"}]}"#)
    XCTAssertEqual(app?["version"] as? String, "2.0")
  }

  func testAppNotInStoreIsNilWithoutError() throws {
    XCTAssertNil(try parse(#"{"resultCount":0,"results":[]}"#))
  }

  func testNonObjectResultIsIgnored() throws {
    XCTAssertNil(try parse(#"{"results":["oops"]}"#))
  }

  func testInvalidJsonIsAnError() {
    XCTAssertThrowsError(try parse("<html>Service Unavailable</html>")) { error in
      XCTAssertEqual(error.localizedDescription, "Unexpected response from the App Store")
    }
  }

  func testMissingResultsIsAnError() {
    XCTAssertThrowsError(try parse(#"{"errorMessage":"Invalid value"}"#))
    XCTAssertThrowsError(try parse("[]"))
  }
}

final class UpdateInfoForAppTests: XCTestCase {
  private func info(_ app: [String: Any]?, current: String?) -> [String: Any] {
    InAppUpdateInfo.updateInfo(
      app: app, currentVersion: current, systemVersion: "17.0", now: date("2026-10-14T00:00:00Z"))
  }

  func testNewerStoreVersionIsAvailable() {
    let info = info(["version": "2.1.0", "releaseNotes": "Bug fixes"], current: "2.0.0")
    XCTAssertEqual(info["updateAvailability"] as? String, "available")
    XCTAssertEqual(info["availableVersion"] as? String, "2.1.0")
    XCTAssertEqual(info["releaseNotes"] as? String, "Bug fixes")
    XCTAssertEqual(info["isImmediateAllowed"] as? Bool, true)
    XCTAssertEqual(info["isFlexibleAllowed"] as? Bool, true)
  }

  func testSameVersionIsNotAvailable() {
    let info = info(["version": "2.0"], current: "2.0.0")
    XCTAssertEqual(info["updateAvailability"] as? String, "not_available")
    XCTAssertEqual(info["isImmediateAllowed"] as? Bool, false)
    XCTAssertEqual(info["isFlexibleAllowed"] as? Bool, false)
    // Still reports what the store has.
    XCTAssertEqual(info["availableVersion"] as? String, "2.0")
  }

  func testOlderStoreVersionIsNotAvailable() {
    // e.g. a TestFlight / dev build ahead of the store.
    XCTAssertEqual(info(["version": "1.9"], current: "1.10")["updateAvailability"] as? String, "not_available")
  }

  func testAppNotInStoreIsNotAvailable() {
    let info = info(nil, current: "1.0")
    XCTAssertEqual(info["updateAvailability"] as? String, "not_available")
    XCTAssertTrue(info["availableVersion"] is NSNull)
    XCTAssertTrue(info["releaseNotes"] is NSNull)
    XCTAssertTrue(info["clientVersionStalenessDays"] is NSNull)
  }

  func testUnknownInstalledVersionIsNotAvailable() {
    XCTAssertEqual(info(["version": "2.0"], current: nil)["updateAvailability"] as? String, "not_available")
  }

  func testNonStringFieldsAreIgnored() {
    let info = info(["version": 2, "releaseNotes": [Any]()], current: "1.0")
    XCTAssertEqual(info["updateAvailability"] as? String, "not_available")
    XCTAssertTrue(info["availableVersion"] is NSNull)
    XCTAssertTrue(info["releaseNotes"] is NSNull)
  }

  func testUpdateNeedingANewerOSIsNotAvailable() {
    let app = ["version": "3.0", "minimumOsVersion": "18.0"]
    XCTAssertEqual(info(app, current: "2.0")["updateAvailability"] as? String, "not_available")
  }

  func testUpdateForThisOSOrOlderIsAvailable() {
    let same = ["version": "3.0", "minimumOsVersion": "17.0"]
    let older = ["version": "3.0", "minimumOsVersion": "15.1"]
    XCTAssertEqual(info(same, current: "2.0")["updateAvailability"] as? String, "available")
    XCTAssertEqual(info(older, current: "2.0")["updateAvailability"] as? String, "available")
  }

  func testStalenessIsWholeDaysSinceRelease() {
    let app = ["version": "2.0", "currentVersionReleaseDate": "2026-10-10T12:00:00Z"]
    XCTAssertEqual(info(app, current: "1.0")["clientVersionStalenessDays"] as? Int, 3)
  }

  func testStalenessIsNeverNegative() {
    // Device clock behind Apple's.
    let app = ["version": "2.0", "currentVersionReleaseDate": "2026-10-20T00:00:00Z"]
    XCTAssertEqual(info(app, current: "1.0")["clientVersionStalenessDays"] as? Int, 0)
  }

  func testStalenessIsUnknownWithoutAnUpdate() {
    let app = ["version": "1.0", "currentVersionReleaseDate": "2026-10-01T00:00:00Z"]
    XCTAssertTrue(info(app, current: "1.0")["clientVersionStalenessDays"] is NSNull)
  }

  func testStalenessIsUnknownForBadDates() {
    let app = ["version": "2.0", "currentVersionReleaseDate": "last tuesday"]
    XCTAssertTrue(info(app, current: "1.0")["clientVersionStalenessDays"] is NSNull)
  }

  func testPlayOnlyFieldsAreZero() {
    let info = info(["version": "2.0"], current: "1.0")
    XCTAssertEqual(info["installStatus"] as? String, "unknown")
    XCTAssertEqual(info["availableVersionCode"] as? Int, 0)
    XCTAssertEqual(info["updatePriority"] as? Int, 0)
    XCTAssertEqual(info["bytesDownloaded"] as? Int, 0)
    XCTAssertEqual(info["totalBytesToDownload"] as? Int, 0)
  }

  func testExposesEveryFieldDartExpects() {
    XCTAssertEqual(
      Set(info(nil, current: "1.0").keys),
      [
        "updateAvailability", "installStatus", "availableVersionCode", "availableVersion", "releaseNotes",
        "isImmediateAllowed", "isFlexibleAllowed", "clientVersionStalenessDays", "updatePriority",
        "bytesDownloaded", "totalBytesToDownload",
      ])
  }
}
