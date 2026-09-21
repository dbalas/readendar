import CoreSpotlight
import Flutter
import UniformTypeIdentifiers
import UIKit

/// Indexes books and quotes for system Spotlight search.
/// Channel: `readendar/spotlight`
enum SpotlightBridge {
  static let channelName = "readendar/spotlight"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "indexItems":
        guard let args = call.arguments as? [String: Any],
              let rawItems = args["items"] as? [[String: Any]]
        else {
          result(
            FlutterError(code: "bad_args", message: "items required", details: nil)
          )
          return
        }
        index(items: rawItems, result: result)
      case "deleteAll":
        CSSearchableIndex.default().deleteAllSearchableItems { error in
          if let error {
            result(
              FlutterError(
                code: "spotlight_error",
                message: error.localizedDescription,
                details: nil
              )
            )
          } else {
            result(nil)
          }
        }
      case "deleteIds":
        guard let args = call.arguments as? [String: Any],
              let ids = args["ids"] as? [String]
        else {
          result(FlutterError(code: "bad_args", message: "ids required", details: nil))
          return
        }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids) { error in
          if let error {
            result(
              FlutterError(
                code: "spotlight_error",
                message: error.localizedDescription,
                details: nil
              )
            )
          } else {
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func index(items: [[String: Any]], result: @escaping FlutterResult) {
    let searchable = items.compactMap { item -> CSSearchableItem? in
      guard let id = item["id"] as? String,
            let title = item["title"] as? String,
            let urlString = item["url"] as? String,
            let url = URL(string: urlString)
      else { return nil }
      let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.text.identifier)
      attributes.title = title
      if let subtitle = item["subtitle"] as? String {
        attributes.contentDescription = subtitle
      }
      attributes.contentURL = url
      attributes.keywords = (item["keywords"] as? [String]) ?? []
      return CSSearchableItem(
        uniqueIdentifier: id,
        domainIdentifier: (item["domain"] as? String) ?? "com.readendar",
        attributeSet: attributes
      )
    }
    CSSearchableIndex.default().indexSearchableItems(searchable) { error in
      if let error {
        result(
          FlutterError(
            code: "spotlight_error",
            message: error.localizedDescription,
            details: nil
          )
        )
      } else {
        result(searchable.count)
      }
    }
  }
}
