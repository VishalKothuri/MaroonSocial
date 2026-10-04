import SwiftUI

/// Place above the native tab bar while another screen is visible. The root
/// supplies navigation; this view never creates a second Tag service/session.
struct ActiveTagBanner: View {
  @Bindable var service: TagService
  let onOpen: () -> Void
  var body: some View {
    if let lobby = service.lobby {
      HStack(spacing: 12) {
        Button(action: onOpen) {
          HStack(spacing: 10) {
            Image(systemName: service.sharing ? "location.fill" : "location.slash.fill")
            VStack(alignment: .leading, spacing: 2) {
              Text(lobby.title).font(.subheadline.bold()).lineLimit(1)
              Text(service.sharing ? "Tag active · location sharing on" : service.playing ? "Tag paused · location off" : service.state == "lobby" ? "Tag lobby · location off" : "Tag results · location off")
                .font(.caption).foregroundStyle(Palette.secondary)
            }
          }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("activeTagOpen")
        Menu {
          if service.sharing { Button("Pause location sharing", systemImage: "pause.circle") { Task { await service.pause() } } }
          Button("Leave Tag", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { Task { await service.leave() } }
        } label: { Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44) }
          .disabled(service.busy).accessibilityLabel("Active Tag options")
      }.padding(.horizontal, 14).padding(.vertical, 5).background(Palette.surface)
        .overlay(alignment: .top) { Divider() }
    }
  }
}
