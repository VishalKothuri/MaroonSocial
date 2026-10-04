import MaroonCore
import SwiftUI

struct ClassesView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var search = ""
  @State private var term = CourseCatalog.terms().first ?? "Fall 2026"
  @State private var level = "All"
  @State private var custom = false
  @State private var visibleLimit = 50
  @State private var activity: CourseActivityService?
  @State private var visible = false
  private var catalog: CourseCatalog? { CourseCatalog.bundled }
  private var courses: [CatalogCourse] { catalog?.search(search, level: level, counts: activity?.counts ?? [:]) ?? [] }
  private var joined: [Course] { store.state.courses.filter { $0.term == term } }
  private var termInfo: CourseTerm? { store.courseTerms.schedule.term(id: term) }
  private var isOpen: Bool { store.courseTerms.canAccess(term: term) }
  private func isJoined(_ code: String) -> Bool { joined.contains { $0.code == code } }
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 14) {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
          ForEach(store.courseTerms.slots) { slot in
            let open = slot.status(at: store.courseTerms.now) == .open
            Button { if term != slot.id { AppHaptics.shared.play(.selection); term = slot.id } } label: {
              VStack(spacing: 4) {
                HStack(spacing: 4) { if !open { Image(systemName: "lock.fill").font(.caption2) }; Text(slot.id).font(.subheadline.bold()).fixedSize(horizontal: false, vertical: true) }
                if !open { Text(slot.opensAt > store.courseTerms.now ? "Opens " + CourseTerm.displayDate(slot.opensAt) : "Calendar pending").font(.caption2).fixedSize(horizontal: false, vertical: true) }
              }.frame(maxWidth: .infinity, minHeight: 44).padding(8)
                .background(term == slot.id && open ? Palette.maroon : Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(open ? Palette.ink : Palette.secondary)
            }.buttonStyle(.plain).disabled(!open)
              .accessibilityIdentifier("semester-\(slot.id)")
              .accessibilityLabel(slot.id + (open ? ", open" : ", locked. " + slot.openingLabel))
              .accessibilityAddTraits(term == slot.id ? .isSelected : [])
          }
        }
        if let error = store.courseTerms.error { Text(error).font(.caption).foregroundStyle(Palette.secondary) }
        if !isOpen {
          EmptyCard(icon: "lock.fill", title: "Class chats are closed", detail: "The next semesters unlock on their opening dates once the official calendar is verified.")
        } else {
        if let termInfo {
          Text(termInfo.closingLabel + ". Chats are removed one month later.").font(.caption).foregroundStyle(Palette.secondary)
        }
        if !joined.isEmpty {
          Text("My classes").font(.headline)
          ForEach(joined) { course in
            NavigationLink { CourseHubView(course: course).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: {
              Card { HStack(spacing: 12) {
                Avatar(symbol: "book.closed.fill")
                VStack(alignment: .leading, spacing: 3) { Text(course.code).font(.headline); Text(course.title).font(.caption).foregroundStyle(Palette.secondary) }
                Spacer(); Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accentText)
              } }
            }.buttonStyle(.plain)
          }
        }
        HStack { Text("Find your class").font(.headline); Spacer(); Button("Add by code") { AppHaptics.shared.play(.selection); custom = true }.font(.subheadline.bold()).frame(minHeight: 44) }
        HStack {
          Image(systemName: "magnifyingglass").font(.body.weight(.semibold)).foregroundStyle(Palette.accentText)
          TextField("Search course code or name", text: $search).textInputAutocapitalization(.characters).autocorrectionDisabled().accessibilityIdentifier("courseSearch")
          if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
        }.padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        HStack {
          Text("\(catalog?.courses.count ?? 0) official courses").font(.caption).foregroundStyle(Palette.secondary)
          Spacer()
          Picker("Level", selection: $level) { Text("All levels").tag("All"); Text("Undergraduate").tag("Undergraduate"); Text("Graduate / professional").tag("Graduate") }.pickerStyle(.menu).font(.caption)
        }
        if let error = activity?.error { Text(error).font(.caption).foregroundStyle(Palette.secondary) }
        if catalog == nil { Text("The course catalog couldn’t load.").font(.headline); Link("Browse the official catalog", destination: URL(string: "https://catalog.tamu.edu/course-search/")!) }
        else if courses.isEmpty { Text("No courses found").foregroundStyle(Palette.secondary); Button("Clear filters") { search = ""; level = "All" } }
        else {
          Text(search.isEmpty ? "Active classes first" : "\(courses.count) matches").font(.caption.bold()).foregroundStyle(Palette.secondary)
          ForEach(courses.prefix(visibleLimit)) { item in
            HStack(alignment: .center, spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                Text(item.code).font(.subheadline.bold())
                Text(item.displayTitle).font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                let count = activity?.counts[item.code] ?? 0
                Text(count > 0 ? "\(count) joined" : "Be the first to join").font(.caption2.weight(.semibold)).foregroundStyle(count > 0 ? Palette.ink : Palette.secondary)
              }.frame(maxWidth: .infinity, alignment: .leading)
              Button(isJoined(item.code) ? "Joined" : "Join") { AppHaptics.shared.play(.impact); store.joinCourse(item.course(term: term)) }
                .font(.subheadline.bold()).buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent)
                .disabled(!isOpen || isJoined(item.code) || store.busy).accessibilityIdentifier("join-\(item.code)")
              Menu { Link("Official course listing", destination: item.sourceURL) } label: {
                Image(systemName: "info.circle").font(.system(size: 18, weight: .semibold)).frame(width: 32, height: 44)
              }.accessibilityLabel("\(item.code) course information")
            }.padding(.vertical, 5)
            Divider()
          }
          if courses.count > visibleLimit { Button("Show more courses") { visibleLimit += 50 }.frame(maxWidth: .infinity, minHeight: 44) }
        }
        Text("Catalog \(catalog?.edition ?? "") · Courses aren’t necessarily offered every semester. Membership is self-selected.").font(.caption).foregroundStyle(Palette.secondary)
        }
        NavigationLink { ActivityListView(filter: .study).appHapticOnOpen().toolbar(.visible, for: .navigationBar) } label: { Label("Study groups", systemImage: "person.2.fill").font(.headline) }.padding(.top, 6)
      }.padding(16)
    }.scrollDismissesKeyboard(.interactively).maroonRefreshable { await store.courseTerms.refresh(); await store.refreshAndWait(); if isOpen { await activity?.refresh(term: term) } }
      .appBackground().toolbar(.hidden, for: .navigationBar)
      .onAppear { visible = true; updateSelection() }.onDisappear { visible = false }
      .onChange(of: store.courseTerms.slots.map(\.id)) { _, _ in updateSelection() }
      .onChange(of: isOpen) { _, open in if !open { custom = false; updateSelection() } }
      .onChange(of: scenePhase) { _, phase in if phase == .active { store.courseTerms.advanceClock(); Task { await store.courseTerms.refresh() } } }
      .onChange(of: search) { _, _ in visibleLimit = 50 }.onChange(of: level) { _, _ in visibleLimit = 50 }
      .onChange(of: store.state.courses) { _, _ in if isOpen { Task { await activity?.refresh(term: term) } } }
      .task { await store.courseTerms.refresh(); updateSelection() }
      .task(id: term) {
        visibleLimit = 50
        if activity == nil { activity = CourseActivityService(social: store.social, fixtureMode: store.fixtureMode) }
        if isOpen { await activity?.refresh(term: term) }
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(activity?.counts.isEmpty == false ? 30 : 60)) } catch { return }
          if visible && store.tab == 1 && scenePhase == .active && isOpen { await activity?.refresh(term: term) }
        }
      }
      .sheet(isPresented: $custom) { AddCourseView(term: term) }
  }
  private func updateSelection() {
    if store.courseTerms.slots.contains(where: { $0.id == term && $0.status(at: store.courseTerms.now) == .open }) { return }
    term = store.courseTerms.slots.first(where: { $0.status(at: store.courseTerms.now) == .open })?.id ?? store.courseTerms.slots.first?.id ?? ""
  }
}
struct AddCourseView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let term: String
  @State private var code = ""
  private var course: CatalogCourse? { CourseCatalog.bundled?.courses.first { $0.code.replacingOccurrences(of: " ", with: "") == code.uppercased().filter { !$0.isWhitespace } } }
  var body: some View {
    NavigationStack { Form {
      TextField("Course code (e.g. HIST 105)", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
      if let course { Text(course.displayTitle).accessibilityIdentifier("officialCourseTitle"); Link("Official course listing", destination: course.sourceURL) }
      else { Text(code.isEmpty ? "Enter an official A&M course code." : "No matching course in the official catalog.").foregroundStyle(Palette.secondary) }
      Text(term).foregroundStyle(Palette.secondary)
      if !store.courseTerms.canAccess(term: term) { Label("This semester’s class chats are closed.", systemImage: "lock.fill") }
      Text("People in the same course and semester join one shared chat. Your username is visible to classmates.").font(.caption)
    }.scrollContentBackground(.hidden).appBackground().navigationTitle("Add class").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Join") {
          guard let course, store.courseTerms.canAccess(term: term) else { return }
          if store.fixtureMode { store.joinCourse(course.course(term: term)); if store.state.courses.contains(where: { $0.id == course.course(term: term).id }) { AppHaptics.shared.play(.success); dismiss() } else { AppHaptics.shared.play(.error) } }
          else { Task { if await store.mutate("course.join", ["code": course.code, "title": course.title, "term": term, "icon": "book.closed.fill"]) { AppHaptics.shared.play(.success); dismiss() } else { AppHaptics.shared.play(.error) } } }
        }.disabled(course == nil || store.busy || !store.courseTerms.canAccess(term: term)) }
      }
    }
  }
}
struct CourseHubView: View {
  @Environment(AppStore.self) private var store
  let course: Course
  var body: some View {
    ScrollView { VStack(alignment: .leading, spacing: 16) {
      if store.courseTerms.canAccess(term: course.term) {
      Card { VStack(alignment: .leading, spacing: 8) {
        Text(course.title).font(.headline)
        Text("\(course.term) · Self-selected membership").font(.caption).foregroundStyle(.secondary)
        NavigationLink { ChatView(id: course.id).appHapticOnOpen() } label: { Label("General chat", systemImage: "bubble.left.and.bubble.right") }.buttonStyle(PrimaryButton())
      } }
      HStack { Text("Study groups").font(.headline); Spacer(); NavigationLink("Browse") { ActivityListView(filter: .study).appHapticOnOpen() } }
      ForEach(store.state.activities.filter { $0.kind == .study && $0.course == course.code && !$0.cancelled }) { activity in
        NavigationLink { ActivityDetailView(id: activity.id).appHapticOnOpen() } label: { ActivityCard(activity: activity) }.buttonStyle(.plain)
      }
      NavigationLink { CreateActivityView(kind: .study, initialCourse: course.code).appHapticOnOpen() } label: { Label("Create study group", systemImage: "plus") }.buttonStyle(.bordered)
      } else {
        EmptyCard(icon: "lock.fill", title: "This semester has closed", detail: "Class conversations are no longer available. Find the next semester in Classes.")
      }
    }.padding(16) }.appBackground().navigationTitle(course.code).navigationBarTitleDisplayMode(.inline)
  }
}
