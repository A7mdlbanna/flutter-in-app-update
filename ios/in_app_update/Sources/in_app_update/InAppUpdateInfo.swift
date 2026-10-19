import Foundation

// App Store lookup → Dart translation. Foundation only, so it can be unit
// tested without Flutter or a simulator (see ios/Tests, scripts/test_ios.sh).
enum InAppUpdateInfo {

  /// Compares dotted versions segment by segment, so "1.10" > "1.9" and
  /// "1.0" == "1.0.0". Each segment counts by its leading digits ("2b" is 2).
  static func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
    let pa = a.components(separatedBy: ".")
    let pb = b.components(separatedBy: ".")
    for i in 0..<max(pa.count, pb.count) {
      let x = i < pa.count ? leadingNumber(pa[i]) : 0
      let y = i < pb.count ? leadingNumber(pb[i]) : 0
      if x != y { return x > y ? .orderedDescending : .orderedAscending }
    }
    return .orderedSame
  }

  /// iTunes lookup URL for `bundleId`, in the `country` store (nil = default US store).
  static func lookupURL(bundleId: String, country: String?, now: Date) -> URL {
    var components = URLComponents(string: "https://itunes.apple.com/lookup")!
    var query = [
      URLQueryItem(name: "bundleId", value: bundleId),
      // Apple's CDN caches lookups for hours; a unique parameter gets a fresh answer.
      URLQueryItem(name: "_", value: String(format: "%.0f", now.timeIntervalSince1970)),
    ]
    if let country { query.append(URLQueryItem(name: "country", value: country.lowercased())) }
    components.queryItems = query
    return components.url!
  }

  /// First app in an iTunes lookup response, or nil when the app isn't in that
  /// store. Throws when the response is malformed.
  static func app(fromLookupData data: Data) throws -> [String: Any]? {
    let json = try? JSONSerialization.jsonObject(with: data)
    guard let results = (json as? [String: Any])?["results"] as? [Any] else {
      throw InAppUpdateError("Unexpected response from the App Store")
    }
    return results.first as? [String: Any]
  }

  /// The update info Dart expects, for the installed `currentVersion` against the store `app`.
  static func updateInfo(
    app: [String: Any]?,
    currentVersion: String?,
    systemVersion: String,
    now: Date
  ) -> [String: Any] {
    let storeVersion = app?["version"] as? String
    let minimumOs = app?["minimumOsVersion"] as? String
    // A newer version this device can't install isn't an update for it.
    let installable = minimumOs.map { compareVersions(systemVersion, $0) != .orderedAscending } ?? true
    var available = false
    if let currentVersion, let storeVersion, installable {
      available = compareVersions(storeVersion, currentVersion) == .orderedDescending
    }

    var stalenessDays: Any = NSNull()
    if available, let releaseDate = app?["currentVersionReleaseDate"] as? String,
      let date = ISO8601DateFormatter().date(from: releaseDate)
    {
      stalenessDays = max(0, Int((now.timeIntervalSince(date) / 86400).rounded(.down)))
    }

    return [
      "updateAvailability": available ? "available" : "not_available",
      "installStatus": "unknown",
      "availableVersionCode": 0,
      "availableVersion": storeVersion ?? NSNull(),
      "releaseNotes": app?["releaseNotes"] as? String ?? NSNull(),
      "isImmediateAllowed": available,
      "isFlexibleAllowed": available,
      "clientVersionStalenessDays": stalenessDays,
      "updatePriority": 0,
      "bytesDownloaded": 0,
      "totalBytesToDownload": 0,
    ]
  }

  private static func leadingNumber(_ segment: String) -> Int {
    Int(segment.prefix { ("0"..."9").contains($0) }) ?? 0
  }
}

struct InAppUpdateError: LocalizedError {
  let message: String

  init(_ message: String) { self.message = message }

  var errorDescription: String? { message }
}
