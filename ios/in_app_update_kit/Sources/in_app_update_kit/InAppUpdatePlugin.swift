import Flutter
import StoreKit
import UIKit

// iOS has no in-app update API: we look the app up on the App Store, compare
// versions, and show its App Store page in-app (SKStoreProductViewController).
public class InAppUpdatePlugin: NSObject, FlutterPlugin, SKStoreProductViewControllerDelegate {
  // Completes the pending startUpdate once the App Store sheet closes. Main thread only.
  private var storeResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "in_app_update_kit", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(InAppUpdatePlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkForUpdate": checkForUpdate(result)
    // The update type doesn't apply on iOS: both flows show the App Store page.
    case "startUpdate": startUpdate(result)
    // The App Store installs updates itself; there's nothing to complete.
    case "completeUpdate": result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func checkForUpdate(_ result: @escaping FlutterResult) {
    let systemVersion = UIDevice.current.systemVersion
    lookupApp { app, error in
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: "E_CHECK_FAILED", message: error.localizedDescription, details: nil))
          return
        }
        result(self.updateInfo(app: app, systemVersion: systemVersion))
      }
    }
  }

  private func startUpdate(_ result: @escaping FlutterResult) {
    let systemVersion = UIDevice.current.systemVersion
    lookupApp { app, error in
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: "E_CHECK_FAILED", message: error.localizedDescription, details: nil))
          return
        }
        let info = self.updateInfo(app: app, systemVersion: systemVersion)
        guard info["updateAvailability"] as? String == "available",
          let trackId = app?["trackId"] as? NSNumber
        else {
          result(
            FlutterError(code: "E_NOT_AVAILABLE", message: "No update is available on the App Store", details: nil))
          return
        }
        if self.storeResult != nil {
          result(FlutterError(code: "E_IN_PROGRESS", message: "The App Store page is already showing", details: nil))
          return
        }
        self.presentStore(trackId: trackId, result: result)
      }
    }
  }

  // MARK: - App Store lookup

  private func lookupApp(_ completion: @escaping ([String: Any]?, Error?) -> Void) {
    let bundleId = Bundle.main.bundleIdentifier ?? ""
    let country: String? =
      if #available(iOS 16, *) { Locale.current.region?.identifier } else { Locale.current.regionCode }
    lookupApp(bundleId: bundleId, country: country) { app, error in
      if app != nil || error != nil || country == nil {
        completion(app, error)
        return
      }
      // Not in the store for the device's region; try the default (US) store.
      self.lookupApp(bundleId: bundleId, country: nil, completion: completion)
    }
  }

  private func lookupApp(
    bundleId: String,
    country: String?,
    completion: @escaping ([String: Any]?, Error?) -> Void
  ) {
    let request = URLRequest(
      url: InAppUpdateInfo.lookupURL(bundleId: bundleId, country: country, now: Date()),
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 15)
    URLSession.shared.dataTask(with: request) { data, _, error in
      guard let data, error == nil else {
        completion(nil, error ?? InAppUpdateError("Empty response from the App Store"))
        return
      }
      do {
        completion(try InAppUpdateInfo.app(fromLookupData: data), nil)
      } catch {
        completion(nil, error)
      }
    }.resume()
  }

  private func updateInfo(app: [String: Any]?, systemVersion: String) -> [String: Any] {
    InAppUpdateInfo.updateInfo(
      app: app,
      currentVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
      systemVersion: systemVersion,
      now: Date())
  }

  // MARK: - App Store page

  private func presentStore(trackId: NSNumber, result: @escaping FlutterResult) {
    storeResult = result
    let store = SKStoreProductViewController()
    store.delegate = self
    // Swipe-to-dismiss wouldn't tell the delegate; make "Done" the only way out.
    store.isModalInPresentation = true
    store.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: trackId]) { loaded, _ in
      DispatchQueue.main.async {
        guard loaded, let presenter = Self.topViewController() else {
          self.storeResult = nil
          self.openAppStore(trackId: trackId, result: result)
          return
        }
        presenter.present(store, animated: true)
      }
    }
  }

  public func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
    let result = storeResult
    storeResult = nil
    // The App Store doesn't say whether the user updated. If they did, iOS
    // relaunches the app on the new version, so getting here means "not yet".
    // Complete after the sheet is gone so a mandatory re-prompt can present again.
    viewController.dismiss(animated: true) { result?("canceled") }
  }

  // Fallback when the in-app sheet can't load: leave for the App Store app.
  private func openAppStore(trackId: NSNumber, result: @escaping FlutterResult) {
    guard let url = URL(string: "itms-apps://apps.apple.com/app/id\(trackId)") else {
      result(FlutterError(code: "E_START_FAILED", message: "Couldn't open the App Store", details: nil))
      return
    }
    UIApplication.shared.open(url) { opened in
      guard opened else {
        result(FlutterError(code: "E_START_FAILED", message: "Couldn't open the App Store", details: nil))
        return
      }
      // Settle once the user is back, like the in-app sheet.
      var observer: NSObjectProtocol?
      observer = NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { _ in
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        result("canceled")
      }
    }
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap(\.windows)
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
