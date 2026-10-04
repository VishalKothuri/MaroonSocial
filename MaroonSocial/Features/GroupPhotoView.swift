import PhotosUI
import SwiftUI

struct GroupPhotoAvatar: View {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  let roomID: String
  var memberKey: String? = nil
  let token: String
  var size: CGFloat = 48
  var publicPreview = false
  @State private var photo: UIImage?
  @State private var photoAuthorizationRevision = -1
  private let revision = GroupPhotoRevision.shared
  private let cache = GroupPhotoCache.shared
  private var scope:GroupPhotoCache.Scope { .init(owner:store.compositions.owner,room:roomID,member:memberKey,publicPreview:publicPreview,revision:revision.value) }
  private var allowed:Bool { !store.fixtureMode && cache.allows(scope) }
  var body: some View {
    Group {
      if allowed,photoAuthorizationRevision == cache.authorizationRevision,let photo { Image(uiImage: photo).resizable().scaledToFill().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.28)) }
      else { GroupAvatarBadge(token: token, size: size) }
    }.accessibilityHidden(true)
      .task(id:"\(scope):\(allowed):\(scenePhase):\(cache.authorizationRevision)") {
        photo=nil
        guard allowed,scenePhase == .active else{return}
        repeat {
          do {
            let data=try await cache.load(scope){try await GroupPhotoService(social:store.social,fixtureMode:false).readPhoto(room:roomID,memberKey:memberKey)}
            try Task.checkCancellation();guard allowed else{return};photo=data.flatMap{UIImage(data:$0)};photoAuthorizationRevision=cache.authorizationRevision
          }catch{if !Task.isCancelled{photo=nil}}
          do{try await Task.sleep(for:.seconds(30))}catch{return}
        }while !Task.isCancelled && allowed && scenePhase == .active
      }
  }
}

struct GroupPhotoPicker: View {
  @Binding var photo: Data?
  var label = "Choose photo"
  @State private var item: PhotosPickerItem?
  @State private var loading = false
  @State private var error: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        if let photo, let image = UIImage(data: photo) { Image(uiImage: image).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 14)) }
        PhotosPicker(selection: $item, matching: .images) { Label(loading ? "Preparing photo…" : label, systemImage: "photo") }.disabled(loading)
        Spacer()
        if photo != nil { Button("Remove", role: .destructive) { photo = nil; item = nil } }
      }.frame(minHeight: 44)
      if let error { Text(error).font(.caption).foregroundStyle(Palette.secondary) }
    }.task(id: item) {
      guard let item else { return }; loading = true; error = nil; defer { loading = false }
      do {
        guard let data = try await item.loadTransferable(type: Data.self) else { throw MediaCompression.Failure.unsupported }
        let ready = try await GroupPhotoService.prepare(data); try Task.checkCancellation(); photo = ready
      } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
  }
}

struct GroupPhotoEditor: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let roomID: String
  var memberKey: String? = nil
  @State private var photo: Data?
  @State private var busy = false
  @State private var error: String?
  var body: some View {
    NavigationStack {
      Form {
        GroupPhotoPicker(photo: $photo)
        Text(memberKey == nil ? "The group photo is visible wherever people can discover or preview this group." : "This photo is visible only to accepted members of this group. It does not change your identity in other groups.").font(.caption).foregroundStyle(Palette.secondary)
        Button("Save photo") { Task { await save(removing: false) } }.disabled(photo == nil || busy)
        Button("Remove current photo", role: .destructive) { Task { await save(removing: true) } }.disabled(busy)
        if let error { Text(error).font(.callout).foregroundStyle(Palette.secondary) }
      }.disabled(busy).scrollContentBackground(.hidden).appBackground().navigationTitle(memberKey == nil ? "Group photo" : "Your group photo").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { DraftCancelButton(hasChanges: photo != nil).disabled(busy) } }
        .interactiveDismissDisabled(busy || photo != nil)
    }
  }
  private func save(removing: Bool) async {
    guard !busy else { return }; busy = true; error = nil; defer { busy = false }
    do { try await GroupPhotoService(social: store.social, fixtureMode: store.fixtureMode).save(removing ? nil : photo, room: roomID, memberKey: memberKey); dismiss() }
    catch { self.error = error.localizedDescription }
  }
}
