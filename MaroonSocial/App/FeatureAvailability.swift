import Foundation

/// The one place that decides which features the app shows.
///
/// 8 Ball, Cup Pong and Campus Tag are hidden, not removed: their views,
/// services, web resources, edge functions and migrations all stay in place.
/// To bring one back, take its kind out of `hiddenGameKinds` or set
/// `campusTagEnabled` to true. UI tests that still exercise the hidden
/// features launch with `--enable-hidden-features`; production builds never
/// pass it.
enum FeatureAvailability {
  /// Launch argument that turns every hidden feature back on (tests only).
  static let enableHiddenFeaturesArgument = "--enable-hidden-features"
  /// Server game kinds that are hidden ("pool" is 8 Ball, "pong" is Cup Pong).
  static let hiddenGameKinds: Set<String> = ["pool", "pong"]
  /// Campus Tag (lobbies, location sharing, the active-match banner).
  static let campusTagEnabled = false
  /// Every game kind the app knows, in display order.
  static let allGameKinds = ["pool", "pong", "chess"]

  private static let launchArguments = ProcessInfo.processInfo.arguments

  static func hiddenFeaturesEnabled(arguments: [String] = launchArguments) -> Bool {
    arguments.contains(enableHiddenFeaturesArgument)
  }

  /// Maps a server kind or a display title ("8 Ball", "Cup Pong", "Chess") to its server kind.
  static func gameKind(for value: String) -> String {
    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "pool", "8 ball", "8-ball", "eight ball": return "pool"
    case "pong", "cup pong", "beer pong": return "pong"
    case "chess": return "chess"
    case let other: return other
    }
  }

  /// Accepts either the server kind or the display title.
  static func isGameAvailable(kind: String, arguments: [String] = launchArguments) -> Bool {
    hiddenFeaturesEnabled(arguments: arguments) || !hiddenGameKinds.contains(gameKind(for: kind))
  }

  /// Accepts either the display title or the server kind.
  static func isGameAvailable(title: String, arguments: [String] = launchArguments) -> Bool {
    isGameAvailable(kind: title, arguments: arguments)
  }

  /// Kinds the app offers right now, in display order.
  static func availableGameKinds(arguments: [String] = launchArguments) -> [String] {
    allGameKinds.filter { isGameAvailable(kind: $0, arguments: arguments) }
  }

  static func isCampusTagAvailable(arguments: [String] = launchArguments) -> Bool {
    campusTagEnabled || hiddenFeaturesEnabled(arguments: arguments)
  }

  /// Copy for a hidden game, e.g. "8 Ball isn’t available right now".
  static func unavailableMessage(for game: String) -> String {
    let kind = gameKind(for: game)
    return "\(allGameKinds.contains(kind) ? OnlineGame.title(kind) : game) isn’t available right now"
  }
}
