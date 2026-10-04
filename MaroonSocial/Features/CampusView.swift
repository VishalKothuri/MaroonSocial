import EventKit
import MapKit
import MaroonCore
import SwiftUI
import SafariServices

struct CampusView: View {
  @Environment(AppStore.self) private var store
  @State private var selected: Date?
  @State private var category = "All"
  @State private var detail: CampusEvent?
  @State private var savedOnly = false
  var visible: [CampusEvent] {
    store.campus.displayEvents(savedIDs: store.state.savedEvents).filter { event in
      let timing = savedOnly ? store.state.savedEvents.contains(event.id)
        : selected.map { Calendar.current.isDate(event.starts, inSameDayAs: $0) }
          ?? ((event.ends ?? event.starts.addingTimeInterval(event.allDay ? 86400 : 3600)) > .now)
      return timing && (category == "All" || event.category == category) && !event.cancelled
    }.sorted { $0.starts < $1.starts }
  }
  private var days: [Date] {
    Array(Set(visible.map { Calendar.current.startOfDay(for: $0.starts) })).sorted()
  }
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 10) {
          NavigationLink { TransitView().toolbar(.visible, for: .navigationBar).appHapticOnOpen() } label: { Pill(text: "Bus routes", icon: "bus") }
          NavigationLink { DiningView().toolbar(.visible, for: .navigationBar).appHapticOnOpen() } label: { Pill(text: "Dining", icon: "fork.knife") }
          NavigationLink { SportsScoresView().toolbar(.visible, for: .navigationBar).appHapticOnOpen() } label: { Pill(text: "Scores", icon: "sportscourt") }.accessibilityIdentifier("campusSportsScores")
          Spacer(minLength: 0)
          Button { AppHaptics.shared.play(.selection); savedOnly.toggle(); selected = nil } label: {
            Image(systemName: savedOnly ? "bookmark.fill" : "bookmark").padding(10)
          }.accessibilityLabel("Saved events").accessibilityIdentifier("savedEventsFilter")
        }
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 7) {
            Button {
              guard selected != nil || savedOnly else { return }
              AppHaptics.shared.play(.selection)
              selected = nil; savedOnly = false
            } label: {
              Text("Upcoming").font(.caption.bold()).padding(.horizontal, 12).frame(height: 51)
                .background(selected == nil && !savedOnly ? Palette.maroon : Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(selected == nil && !savedOnly ? Palette.onAccent : Palette.ink)
            }.accessibilityIdentifier("campusUpcoming")
            ForEach(0..<21) { offset in
              let date = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
              let active = selected.map { Calendar.current.isDate(date, inSameDayAs: $0) } ?? false
              Button {
                guard !active || savedOnly else { return }
                AppHaptics.shared.play(.selection)
                selected = date; savedOnly = false
              } label: {
                VStack(spacing: 3) {
                  Text(date, format: .dateTime.weekday(.abbreviated)).font(.system(size: 9, weight: .semibold))
                  Text(date, format: .dateTime.day()).font(.headline)
                }.frame(width: 43, height: 51)
                  .background(active ? Palette.maroon : Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                  .foregroundStyle(active ? Palette.onAccent : Palette.ink)
              }.accessibilityIdentifier("campusDay-\(offset)")
            }
          }
        }
        HStack(spacing: 8) {
          ForEach(["All", "Campus", "Rec", "Sports"], id: \.self) { value in
            Button {
              guard category != value else { return }
              AppHaptics.shared.play(.selection)
              category = value
            } label: { Pill(text: value, selected: category == value) }
          }
        }
        HStack {
          Text(savedOnly ? "Saved events" : selected == nil ? "Upcoming events" : "Events for this day").font(.headline)
          Spacer()
          if store.campus.loading { ProgressView().controlSize(.small) }
          else { Text("\(visible.count)").font(.caption).foregroundStyle(.secondary) }
        }
        if let error = store.campus.error {
          HStack(alignment: .top) {
            Text(error).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
              AppHaptics.shared.play(.impact)
              Task { await store.campus.refresh(force: true) }
            }.font(.caption.bold())
          }
        }
        if visible.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text(savedOnly ? "No saved events yet" : "No events match this filter").font(.subheadline.bold())
            Text(savedOnly ? "Save a campus event to keep it here." : "Browse upcoming days or switch categories. The university’s full calendar may list more events.")
              .font(.caption).foregroundStyle(.secondary)
            if selected != nil || category != "All" {
              Button("Show all upcoming events") {
                AppHaptics.shared.play(.selection)
                selected = nil; category = "All"; savedOnly = false
              }
                .font(.subheadline.bold())
            }
          }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
        }
        ForEach(days, id: \.self) { day in
          Text(day, format: .dateTime.weekday(.wide).month(.abbreviated).day())
            .font(.caption.bold()).foregroundStyle(.secondary).padding(.top, 4)
          VStack(spacing: 0) {
            ForEach(visible.filter { Calendar.current.isDate($0.starts, inSameDayAs: day) }) { event in
              Button { AppHaptics.shared.play(.impact); detail = event } label: {
                HStack(alignment: .top, spacing: 12) {
                  Text(event.allDay ? "ALL\nDAY" : event.starts.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.accentText)
                    .frame(width: 48, alignment: .leading)
                  VStack(alignment: .leading, spacing: 5) {
                    Text(event.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                    if !event.location.isEmpty {
                      Text(event.location).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Text(event.category).font(.system(size: 10)).foregroundStyle(.secondary)
                  }.frame(maxWidth: .infinity, alignment: .leading)
                  Image(systemName: store.state.savedEvents.contains(event.id) ? "bookmark.fill" : "chevron.right")
                    .font(.caption2).foregroundStyle(.secondary)
                }.padding(14)
              }.buttonStyle(.plain).accessibilityIdentifier("campusEvent-\(event.id)")
              if event.id != visible.filter({ Calendar.current.isDate($0.starts, inSameDayAs: day) }).last?.id {
                Divider().padding(.leading, 74)
              }
            }
          }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 17))
        }
        if let fetched = store.campus.fetchedAt {
          Text("Official A&M feeds · updated \(fetched.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
            .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        Link("Full A&M calendar", destination: URL(string: "https://calendar.tamu.edu/")!).font(.caption.bold())
      }.padding(16)
    }.maroonRefreshable(scope: "campus") { await store.campus.refresh(force: true) }.appBackground()
      .toolbar(.hidden, for: .navigationBar)
      .sheet(item: $detail) { EventDetailView(event: $0) }
      .task { await store.campus.refresh() }
  }
}
struct EventDetailView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let event: CampusEvent
  @State private var calendarMessage: String?
  @State private var addingCalendar = false
  @State private var addedToCalendar = false
  @State private var saving = false
  @State private var sportsRoom: String?
  @State private var visible = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Pill(text: event.category)
          Text(event.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
          Label(
            event.starts.formatted(date: .complete, time: event.allDay ? .omitted : .shortened),
            systemImage: "calendar")
          if !event.location.isEmpty { Label(event.location, systemImage: "mappin.and.ellipse") }
          Text(event.details).font(.subheadline).lineSpacing(5)
          Button(store.state.savedEvents.contains(event.id) ? "Saved" : "Save event") {
            AppHaptics.shared.play(.impact)
            saving = true
            Task {
              let result = await store.perform("save_event", ["event_id": event.id, "saved": !store.state.savedEvents.contains(event.id)])
              if visible, !Task.isCancelled { AppHaptics.shared.play(result != nil ? .success : .error) }
              if result == nil { calendarMessage = store.notice ?? "Couldn’t save the event. Please try again."; store.notice = nil }
              saving = false
            }
          }.buttonStyle(OutlinedActionStyle(emphasized: !store.state.savedEvents.contains(event.id)))
            .disabled(saving).accessibilityIdentifier("eventSave")
          Button(addedToCalendar ? "Added to iPhone Calendar" : addingCalendar ? "Adding to Calendar…" : "Add to iPhone Calendar") {
            AppHaptics.shared.play(.impact)
            addingCalendar = true
            Task {
              defer { addingCalendar = false }
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
                  addedToCalendar = true
                  calendarMessage = "Added to your calendar."
                  if visible, !Task.isCancelled { AppHaptics.shared.play(.success) }
                } else {
                  calendarMessage = "Calendar access is off. You can enable it in iPhone Settings, then try again."
                  if visible, !Task.isCancelled { AppHaptics.shared.play(.warning) }
                }
              } catch {
                calendarMessage = "Couldn’t add this event. \(error.localizedDescription)"
                if visible, !Task.isCancelled { AppHaptics.shared.play(.error) }
              }
            }
          }.buttonStyle(OutlinedActionStyle()).disabled(addingCalendar || addedToCalendar)
            .accessibilityIdentifier("addToCalendar")
          if event.category == "Sports" {
            SportsEventHeader(event: event)
            Text(
              "Game chat opens 30 minutes before the scheduled start."
            ).font(.caption)
            if event.canOpenSportsChat(at: .now) {
              Button("Open game chat") {
                AppHaptics.shared.play(.impact)
                saving = true
                Task {
                  let result = await store.perform("join_sports", ["event_id": event.id])
                  if let room = result?.resourceID { sportsRoom = room }
                  else {
                    if visible, !Task.isCancelled { AppHaptics.shared.play(.error) }
                    calendarMessage = store.notice ?? "This game chat is not available yet."; store.notice = nil
                  }
                  saving = false
                }
              }.buttonStyle(OutlinedActionStyle()).disabled(saving)
            }
          }
          if let url = URL(string: event.url) {
            Link("Details on the official A&M calendar", destination: url)
              .buttonStyle(OutlinedActionStyle())
          }
          Text("Source: calendar.tamu.edu. Event times and availability can change.").font(.caption)
            .foregroundStyle(.secondary)
        }.padding(24)
      }.appBackground()
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .navigationDestination(item: $sportsRoom) { ChatView(id: $0) }
        .navigationTitle("Event details").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Done") { AppHaptics.shared.play(.impact); dismiss() } }
        .alert("Event", isPresented: Binding(get: { calendarMessage != nil }, set: { if !$0 { calendarMessage = nil } })) {
          Button("OK") { calendarMessage = nil }
        } message: { Text(calendarMessage ?? "") }
    }.presentationDragIndicator(.visible)
  }
}
struct SavedEventsView: View {
  @Environment(AppStore.self) private var store
  @State private var detail: CampusEvent?
  private var events: [CampusEvent] {
    store.campus.displayEvents(savedIDs: store.state.savedEvents).filter { store.state.savedEvents.contains($0.id) }.sorted { $0.starts < $1.starts }
  }
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        if events.isEmpty {
          EmptyCard(icon: "calendar.badge.checkmark", title: "Make room for a good plan",
                    detail: "Save an event from Campus to find it here. Events outside the current campus feed are no longer shown.")
        }
        ForEach(events) { event in
          Button { AppHaptics.shared.play(.impact); detail = event } label: {
            Card {
              VStack(alignment: .leading, spacing: 9) {
                Text(event.title).font(.headline)
                Text(event.starts, format: .dateTime.weekday().month().day().hour().minute())
                  .font(.caption).foregroundStyle(.secondary)
                if !event.location.isEmpty { Label(event.location, systemImage: "mappin").font(.caption) }
              }
            }
          }.buttonStyle(.plain)
        }
      }.padding(20)
    }.appBackground().navigationTitle("Saved events").navigationBarTitleDisplayMode(.inline)
      .sheet(item: $detail) { EventDetailView(event: $0) }
  }
}
struct TransitView: View {
  @Environment(AppStore.self) private var store
  @State private var query = ""
  @State private var liveMap = false
  @FocusState private var searchFocused: Bool
  private var routes: [BusRoute] {
    store.campus.routes.filter { query.isEmpty || "\($0.id) \($0.name)".localizedCaseInsensitiveContains(query) }
  }
  private var stops: [BusStop] {
    store.campus.stops.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
  }
  var body: some View {
    List {
      Section {
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          TextField("Route or stop", text: $query).focused($searchFocused)
            .autocorrectionDisabled().submitLabel(.search).onSubmit { searchFocused = false }
            .accessibilityIdentifier("transitSearch")
          if !query.isEmpty {
            Button {
              AppHaptics.shared.play(.selection)
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }.accessibilityLabel("Clear route search").buttonStyle(.plain)
          }
        }.padding(.vertical, 4)
      }
      Section {
        Button { AppHaptics.shared.play(.impact); liveMap = true } label: {
          Label("Live buses & departure times", systemImage: "bus.fill")
        }
        Text(
          "Browse current routes and stops below, or open the official live map for buses, departures and service changes."
        ).font(.caption).foregroundStyle(.secondary)
      }
      Section("Routes") {
        if let date = store.campus.transitFetchedAt {
          Text("Route snapshot: \(date.formatted(date: .abbreviated, time: .shortened))").font(
            .caption
          ).foregroundStyle(.secondary)
        }
        if store.campus.transitError != nil {
          Text(store.campus.transitError ?? "").font(
            .caption
          ).foregroundStyle(.secondary)
        }
        if routes.isEmpty { Text("No matching routes").foregroundStyle(.secondary) }
        ForEach(routes) { route in
          HStack {
            Text(route.id).font(.headline).frame(width: 60)
            Text(route.name)
          }
        }
      }
      Section("Stops") {
        if stops.isEmpty { Text("No matching stops").foregroundStyle(.secondary) }
        ForEach(stops) { stop in
          Button {
            AppHaptics.shared.play(.impact)
            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
              latitude: stop.latitude, longitude: stop.longitude)))
            item.name = stop.name
            item.openInMaps()
          } label: {
            Label(stop.name, systemImage: "mappin.circle")
          }
        }
      }
    }.scrollContentBackground(.hidden).appBackground().scrollDismissesKeyboard(.interactively)
      .navigationTitle("AggieSpirit").navigationBarTitleDisplayMode(.inline)
      .task { await store.campus.refreshTransit() }
      .maroonRefreshable(scope: "transit") { await store.campus.refreshTransit(force: true) }
      .sheet(isPresented: $liveMap) { OfficialCampusBrowser(url: URL(string: "https://aggiespirit.ts.tamu.edu/RouteMap")!) }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if searchFocused { KeyboardDismissButton { searchFocused = false } }
        }
      }
  }
}
struct DiningView: View {
  @State private var page: CampusBrowserPage?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Aggie Dining").font(.title2.bold())
        Text("Current menus, opening hours and dietary details from the official dining provider.")
          .font(.subheadline).foregroundStyle(.secondary)
        diningRow("Menus & dining locations", detail: "Browse dining halls and restaurants", icon: "fork.knife", path: "")
        diningRow("Hours of operation", detail: "Check today before heading over", icon: "clock", path: "/hours-of-operation")
        diningRow("Maroon Meals", detail: "See participating spots and options", icon: "takeoutbag.and.cup.and.straw", path: "/maroon-meals")
        Link(destination: URL(string: "https://facilities.tamu.edu/departments/dining.html")!) {
          Label("University dining information", systemImage: "arrow.up.right")
        }.font(.subheadline)
        Text("Dining pages open inside the app. The provider does not currently allow a direct menu feed, so hours and menus are displayed from its site.")
          .font(.caption).foregroundStyle(.secondary)
      }.padding(18)
    }.appBackground().navigationTitle("Dining").navigationBarTitleDisplayMode(.inline)
      .sheet(item: $page) { OfficialCampusBrowser(url: $0.url) }
  }
  private func diningRow(_ title: String, detail: String, icon: String, path: String) -> some View {
    Button {
      AppHaptics.shared.play(.impact)
      page = CampusBrowserPage(url: URL(string: "https://dineoncampus.com/tamu" + path)!)
    } label: {
      HStack(spacing: 14) {
        Image(systemName: icon).font(.title3).foregroundStyle(Palette.accentText).frame(width: 30)
        VStack(alignment: .leading, spacing: 5) {
          Text(title).font(.headline)
          Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.caption)
      }.padding(17).background(Palette.surface, in: RoundedRectangle(cornerRadius: 17))
    }.buttonStyle(.plain)
  }
}
private struct CampusBrowserPage: Identifiable { let id = UUID(); let url: URL }
struct OfficialCampusBrowser: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> SFSafariViewController {
    let controller = SFSafariViewController(url: url)
    controller.preferredControlTintColor = UIColor(Palette.accentText)
    return controller
  }
  func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
