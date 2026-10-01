import CoreLocation
import SwiftUI

@Observable @MainActor final class TagLocation: NSObject, @preconcurrency CLLocationManagerDelegate
{
  var heading: Double = 0
  var coordinate: CLLocationCoordinate2D?
  var denied = false
  private let manager = CLLocationManager()
  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
  }
  func start() {
    manager.requestWhenInUseAuthorization()
    if manager.authorizationStatus == .authorizedWhenInUse
      || manager.authorizationStatus == .authorizedAlways
    {
      manager.startUpdatingLocation()
      manager.startUpdatingHeading()
    }
  }
  func stop() {
    manager.stopUpdatingHeading()
    manager.stopUpdatingLocation()
    coordinate = nil
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    denied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    if manager.authorizationStatus == .authorizedWhenInUse {
      manager.startUpdatingLocation()
      manager.startUpdatingHeading()
    }
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    coordinate = locations.last?.coordinate
  }
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
  }
}
struct TagView: View {
  @State private var location = TagLocation()
  @State private var started: Date?
  @State private var role = "Seeker"
  @Environment(\.scenePhase) private var phase
  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        SectionHeading(title: "Hide. Seek.\nGig ’em.", eyebrow: "Campus Tag")
        Picker("Your role", selection: $role) {
          Text("Seeker").tag("Seeker")
          Text("Hider").tag("Hider")
        }.pickerStyle(.segmented).disabled(started != nil)
        ZStack {
          Circle().stroke(Palette.lime.opacity(0.15), lineWidth: 1)
          Circle().stroke(Palette.lime.opacity(0.15), lineWidth: 1).padding(40)
          Circle().stroke(Palette.lime.opacity(0.15), lineWidth: 1).padding(80)
          ForEach(0..<12) { i in
            Rectangle().fill(Palette.lime.opacity(0.5)).frame(width: 1, height: 8).offset(y: -125)
              .rotationEffect(.degrees(Double(i) * 30))
          }
          VStack(spacing: 10) {
            Image(systemName: "location.north.fill").font(.system(size: 58, weight: .light))
              .rotationEffect(.degrees(-location.heading))
            Text(started == nil ? "READY WHEN YOU ARE" : "COMPASS PRACTICE").font(
              .system(size: 10, weight: .bold)
            ).tracking(2)
            if let started { Text(started, style: .timer).font(.title.monospacedDigit()) }
          }.foregroundStyle(Palette.lime)
        }.frame(height: 290).padding(20).background(
          Palette.ink, in: RoundedRectangle(cornerRadius: 28))
        Card {
          VStack(alignment: .leading, spacing: 12) {
            Text(started == nil ? "Start with a practice round" : "Practice round in progress")
              .font(.headline)
            Text(
              "Explore the compass on your own device. No location is uploaded, and no other players are tracked in this preview."
            ).font(.subheadline).foregroundStyle(.secondary)
            if location.denied {
              Text("Location is off. Enable it in iPhone Settings to test the compass.").font(
                .caption
              ).foregroundStyle(Palette.maroon)
            }
          }
        }
        if started == nil {
          Button("Start practice") {
            started = .now
            location.start()
          }.buttonStyle(PrimaryButton())
        } else {
          Button("End practice") {
            started = nil
            location.stop()
          }.buttonStyle(PrimaryButton())
        }
        Text(
          "Private multiplayer lobbies, approximate player hints and catch confirmation need the game server. Practice pauses when the app leaves the foreground."
        ).font(.caption).foregroundStyle(.secondary)
      }.padding(22)
    }.appBackground().navigationTitle("Campus Tag").navigationBarTitleDisplayMode(.inline)
      .onDisappear {
        location.stop()
        started = nil
      }.onChange(of: phase) { _, p in
        if p != .active {
          location.stop()
          started = nil
        }
      }
  }
}
