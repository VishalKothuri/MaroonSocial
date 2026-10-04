import Foundation
import Observation
import SwiftUI
import UIKit

/// Short, semantic feedback for intentional interactions. Never call this from
/// polling, view refresh, typing, or native controls that already provide it.
@Observable @MainActor final class AppHaptics {
  enum Event: Equatable { case selection, impact, success, warning, error }
  struct Preferences {
    var readEnabled: () -> Bool?
    var writeEnabled: (Bool) -> Void
    static func local(_ defaults: UserDefaults = .standard, key: String = "maroon.appHapticsEnabled") -> Self {
      return Self(readEnabled: { defaults.object(forKey: key) as? Bool }, writeEnabled: { defaults.set($0, forKey: key) })
    }
    static func forApplication(arguments: [String], defaults: UserDefaults = .standard) -> Self {
      let fixtures = arguments.contains("--uitesting") || arguments.contains("--uitesting-preserve")
      guard fixtures else { return .local(defaults) }
      let key = "maroon.appHapticsEnabled.uiTests"
      if arguments.contains("--uitesting"), !arguments.contains("--uitesting-preserve") { defaults.removeObject(forKey: key) }
      return .local(defaults, key: key)
    }
  }
  static let shared = AppHaptics(preferences: .forApplication(arguments: ProcessInfo.processInfo.arguments))
  var enabled: Bool {
    didSet {
      guard enabled != oldValue else { return }
      preferences.writeEnabled(enabled)
      if !enabled { lastEvent = nil }
    }
  }
  @ObservationIgnored private let preferences: Preferences
  @ObservationIgnored private let clock: () -> TimeInterval
  @ObservationIgnored private let isActive: @MainActor () -> Bool
  @ObservationIgnored private let feedback: (Event) -> Void
  @ObservationIgnored private var lastEvent: (event: Event, time: TimeInterval)?
  static let repeatInterval: TimeInterval = 0.12

  init(preferences: Preferences = .local(), clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
       isActive: @escaping @MainActor () -> Bool = { UIApplication.shared.applicationState == .active },
       feedback: ((Event) -> Void)? = nil) {
    self.preferences = preferences; self.clock = clock; self.isActive = isActive
    enabled = preferences.readEnabled() ?? true
    if let feedback { self.feedback = feedback }
    else {
      let native = NativeHapticFeedback()
      self.feedback = { native.play($0) }
    }
  }
  /// Returns admission, not proof of a physical vibration (Simulator has none).
  @discardableResult func play(_ event: Event) -> Bool {
    guard enabled, isActive() else { return false }
    let now = clock()
    if event == .selection || event == .impact, let lastEvent, lastEvent.event == event, now >= lastEvent.time, now - lastEvent.time < Self.repeatInterval { return false }
    lastEvent = (event, now)
    feedback(event)
    return true
  }
}

@MainActor private final class NativeHapticFeedback {
  private let selection = UISelectionFeedbackGenerator()
  private let impact = UIImpactFeedbackGenerator(style: .light)
  private let notification = UINotificationFeedbackGenerator()
  func play(_ event: AppHaptics.Event) {
    switch event {
    case .selection: selection.selectionChanged()
    case .impact: impact.impactOccurred(intensity: 0.7)
    case .success: notification.notificationOccurred(.success)
    case .warning: notification.notificationOccurred(.warning)
    case .error: notification.notificationOccurred(.error)
    }
  }
}

/// Use on selected NavigationLink destinations, never every button or on a
/// root view. SwiftUI retains this flag while another destination covers it,
/// preventing a second pulse when going Back or when its data refreshes.
private struct NavigationOpenHaptic: ViewModifier {
  @State private var announced = false
  func body(content: Content) -> some View {
    content.onAppear {
      guard !announced else { return }
      announced = true
      AppHaptics.shared.play(.selection)
    }
  }
}
extension View {
  func appHapticOnOpen() -> some View { modifier(NavigationOpenHaptic()) }
}
