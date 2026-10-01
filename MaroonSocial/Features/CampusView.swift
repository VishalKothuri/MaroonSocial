import EventKit
import MapKit
import MaroonCore
import SwiftUI

struct CampusView: View {
  @Environment(AppStore.self) private var store
  @State private var selected = Calendar.current.startOfDay(for: .now)
  @State private var category = "All"
  @State private var detail: CampusEvent?
  var visible: [CampusEvent] {
    store.campus.events.filter {
      Calendar.current.isDate($0.starts, inSameDayAs: selected)
        && (category == "All" || $0.category == category) && !$0.cancelled
    }
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        SectionHeading(
          title: "Your campus,\nin the loop.",
          eyebrow: Date.now.formatted(.dateTime.month(.wide).year()))
        HStack(spacing: 12) {
          NavigationLink {
            TransitView()
          } label: {
            Pill(text: "Bus routes", icon: "bus")
          }
          NavigationLink {
            DiningView()
          } label: {
            Pill(text: "Dining", icon: "fork.knife")
          }
          Spacer()
        }
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(0..<21) { offset in
              let date = Calendar.current.date(
                byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
              Button {
                selected = date
              } label: {
                VStack(spacing: 8) {
                  Text(date, format: .dateTime.weekday(.abbreviated)).font(
                    .system(size: 10, weight: .bold))
                  Text(date, format: .dateTime.day()).font(.title3.bold())
                }.frame(width: 47, height: 66).background(
                  Calendar.current.isDate(date, inSameDayAs: selected)
                    ? Palette.maroon : Color.white, in: RoundedRectangle(cornerRadius: 16)
                ).foregroundStyle(
                  Calendar.current.isDate(date, inSameDayAs: selected) ? .white : Palette.ink)
              }
            }
          }
        }
        HStack {
          ForEach(["All", "Campus", "Rec", "Sports"], id: \.self) { c in
            Button {
              category = c
            } label: {
              Pill(text: c, selected: category == c)
            }
          }
        }
        if let error = store.campus.error { Text(error).font(.caption).foregroundStyle(.secondary) }
        if let fetched = store.campus.fetchedAt {
          Text(
            "Official A&M feeds · refreshed \(fetched.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
          ).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        if visible.isEmpty {
          EmptyCard(
            icon: "calendar", title: "A little breathing room",
            detail:
              "No events in this feed for the selected day. Check the official calendar for changes."
          )
        }
        ForEach(visible) { event in
          Button {
            detail = event
          } label: {
            Card {
              HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 3) {
                  Text(event.starts, format: .dateTime.day()).font(.title.bold())
                  Text(event.starts, format: .dateTime.month(.abbreviated)).font(.caption.bold())
                }.foregroundStyle(Palette.maroon).frame(width: 42)
                VStack(alignment: .leading, spacing: 9) {
                  Text(event.category.uppercased()).font(.system(size: 9, weight: .bold)).tracking(
                    1.5
                  ).foregroundStyle(.secondary)
                  Text(event.title).font(.system(size: 18, weight: .semibold))
                    .multilineTextAlignment(.leading)
                  Text(
                    event.allDay
                      ? "All day" : event.starts.formatted(date: .omitted, time: .shortened)
                  ).font(.caption)
                  if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin").font(.caption).foregroundStyle(
                      .secondary
                    ).lineLimit(2)
                  }
                }
                Spacer(minLength: 0)
                if store.state.savedEvents.contains(event.id) {
                  Image(systemName: "bookmark.fill").font(.caption)
                }
              }
            }
          }.buttonStyle(.plain)
        }
        Link("Open the full A&M calendar", destination: URL(string: "https://calendar.tamu.edu/")!)
          .font(.subheadline)
      }.padding(20)
    }.refreshable { await store.campus.refresh(force: true) }.appBackground().navigationTitle(
      "Campus"
    ).navigationBarTitleDisplayMode(.inline).sheet(item: $detail) { EventDetailView(event: $0) }
  }
}
struct EventDetailView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let event: CampusEvent
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Pill(text: event.category)
          SectionHeading(title: event.title)
          Label(
            event.starts.formatted(date: .complete, time: event.allDay ? .omitted : .shortened),
            systemImage: "calendar")
          if !event.location.isEmpty { Label(event.location, systemImage: "mappin.and.ellipse") }
          Text(event.details).font(.subheadline).lineSpacing(5)
          Button(store.state.savedEvents.contains(event.id) ? "Saved" : "Save event") {
            if store.state.savedEvents.contains(event.id) {
              store.state.savedEvents.remove(event.id)
            } else {
              store.state.savedEvents.insert(event.id)
            }
            store.save()
          }.buttonStyle(PrimaryButton())
          Button("Add to iPhone Calendar") {
            Task {
              let calendar = EKEventStore()
              do {
                if try await calendar.requestWriteOnlyAccessToEvents() {
                  let e = EKEvent(eventStore: calendar)
                  e.title = event.title
                  e.startDate = event.starts
                  e.endDate =
                    event.ends ?? event.starts.addingTimeInterval(event.allDay ? 86400 : 3600)
                  e.isAllDay = event.allDay
                  e.location = event.location
                  e.url = URL(string: event.url)
                  e.calendar = calendar.defaultCalendarForNewEvents
                  try calendar.save(e, span: .thisEvent)
                  store.notice = "Added to your calendar."
                }
              } catch { store.notice = error.localizedDescription }
            }
          }
          if event.category == "Sports" {
            Text(
              "Game chat opens 30 minutes before the scheduled start. Live scores need a connected sports feed."
            ).font(.caption)
            if event.canOpenSportsChat(at: .now) {
              Button("Open game chat") {
                let id = "sports-\(event.id)"
                if !store.state.conversations.contains(where: { $0.id == id }) {
                  store.state.conversations.append(
                    Conversation(id: id, title: event.title, subtitle: "Game chat"))
                  store.save()
                }
                dismiss()
                store.tab = 4
              }
            }
          }
          if let url = URL(string: event.url) {
            Link("Details on the official A&M calendar", destination: url)
          }
          Text("Source: calendar.tamu.edu. Event times and availability can change.").font(.caption)
            .foregroundStyle(.secondary)
        }.padding(24)
      }.appBackground().toolbar { Button("Done") { dismiss() } }
    }
  }
}
struct TransitView: View {
  @Environment(AppStore.self) private var store
  @State private var query = ""
  var body: some View {
    List {
      Section {
        Link(
          "Open live AggieSpirit route map",
          destination: URL(string: "https://aggiespirit.ts.tamu.edu/RouteMap")!)
        Text(
          "Official route catalog and bus stops. This app does not display live bus locations or arrival estimates yet."
        ).font(.caption).foregroundStyle(.secondary)
      }
      Section("Routes") {
        if let date = store.campus.transitFetchedAt {
          Text("Route snapshot: \(date.formatted(date: .abbreviated, time: .shortened))").font(
            .caption
          ).foregroundStyle(.secondary)
        }
        if store.campus.warnings.contains("Routes") || store.campus.warnings.contains("Stops") {
          Text("Live refresh is unavailable. Check the official route map for changes.").font(
            .caption
          ).foregroundStyle(.secondary)
        }
        ForEach(
          store.campus.routes.filter {
            query.isEmpty || "\($0.id) \($0.name)".localizedCaseInsensitiveContains(query)
          }
        ) { route in
          HStack {
            Text(route.id).font(.headline).frame(width: 60)
            Text(route.name)
          }
        }
      }
      Section("Stops") {
        ForEach(
          store.campus.stops.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
          }
        ) { stop in
          Button {
            MKMapItem(
              placemark: MKPlacemark(
                coordinate: CLLocationCoordinate2D(
                  latitude: stop.latitude, longitude: stop.longitude))
            ).openInMaps()
          } label: {
            Label(stop.name, systemImage: "mappin.circle")
          }
        }
      }
    }.searchable(text: $query, prompt: "Route or stop").navigationTitle("AggieSpirit")
      .navigationBarTitleDisplayMode(.inline)
  }
}
struct DiningView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        SectionHeading(title: "What sounds good?", eyebrow: "Aggie Dining")
        Image(systemName: "fork.knife.circle").font(.system(size: 70, weight: .ultraLight))
          .foregroundStyle(Palette.maroon)
        Text("Today’s menus and hours").font(.title2.bold())
        Text(
          "The dining provider currently blocks automated access. Open the official dining site for today’s menus, hours and dietary information."
        ).foregroundStyle(.secondary)
        Link(destination: URL(string: "https://dineoncampus.com/tamu")!) {
          Label("Open Aggie Dining", systemImage: "arrow.up.right")
        }.buttonStyle(PrimaryButton())
        Link(
          "A&M Dining information",
          destination: URL(string: "https://facilities.tamu.edu/departments/dining.html")!)
        Text("No estimated menus or opening hours are shown.").font(.caption).foregroundStyle(
          .secondary)
      }.padding(24)
    }.appBackground().navigationTitle("Dining").navigationBarTitleDisplayMode(.inline)
  }
}
