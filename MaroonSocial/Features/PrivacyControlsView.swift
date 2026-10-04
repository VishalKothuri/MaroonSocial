import SwiftUI
import UniformTypeIdentifiers

struct PrivacyControlsView: View {
  @State private var service: AccountControlsService
  @State private var unblocking: PrivateBlock?
  @State private var exporting = false
  @State private var document = AccountExportDocument()
  @State private var exportTask: Task<Void, Never>?
  @State private var saved = false
  init(social: SocialService) { _service = State(initialValue: AccountControlsService(social: social)) }
  var body: some View {
    List {
      Section {
        Text("Save a private JSON copy of your profile, authored posts and replies, sent messages, memberships, preferences, submitted reports and media metadata.").font(.subheadline)
        Text("The file excludes other people’s messages, media files, credentials, verification hashes and precise locations. Keep it somewhere private.").font(.caption).foregroundStyle(.secondary)
        Button("Prepare account export", systemImage: "square.and.arrow.up") {
          saved = false
          exportTask = Task {
            if let data = await service.exportData(), !Task.isCancelled { document = AccountExportDocument(data: data); exporting = true }
          }
        }.disabled(service.busy).accessibilityIdentifier("prepareAccountExport")
        if let progress = service.exportProgress {
          HStack { ProgressView(); Text("Preparing \(progress.lowercased())…").font(.caption); Spacer(); Button("Cancel") { exportTask?.cancel() } }
        }
        if saved { Label("Export saved", systemImage: "checkmark.circle").font(.caption) }
      } header: { Text("Your data") }
      if let error = service.error { Section { Text(error).foregroundStyle(Palette.accentText).font(.callout); Button("Try again") { Task { await service.act("blocks") } } } }
      Section {
        if service.blocks.isEmpty { Text(service.loaded ? "No blocked accounts" : "Loading blocked accounts…").foregroundStyle(.secondary) }
        ForEach(service.blocks) { block in
          VStack(alignment: .leading, spacing: 8) {
            Text(block.label).font(.subheadline).lineLimit(3)
            HStack {
              Text(block.createdAt, format: .dateTime.month(.abbreviated).day().year()).font(.caption).foregroundStyle(.secondary)
              Spacer()
              Button("Unblock", role: .destructive) { unblocking = block }.font(.caption.bold()).disabled(service.busy)
                .accessibilityIdentifier("unblock-\(block.id)")
            }
          }.padding(.vertical, 5)
        }
      } header: { Text("Blocked accounts") } footer: {
        Text("Labels show the context you blocked, without resolving anonymous authors to usernames. Older blocks may have a private generic label. Unblocking permits future requests; it does not reconnect accounts or reopen closed conversations. Random-chat guest blocks belong to that separate guest session.")
      }
    }.scrollContentBackground(.hidden).appBackground().navigationTitle("Privacy controls").navigationBarTitleDisplayMode(.inline)
      .task { await service.act("blocks") }.maroonRefreshable(scope: "blocks") { await service.act("blocks") }
      .onDisappear { exportTask?.cancel() }
      .confirmationDialog("Unblock this account?", isPresented: Binding(get: { unblocking != nil }, set: { if !$0 { unblocking = nil } }), titleVisibility: .visible) {
        Button("Unblock account", role: .destructive) {
          if let block = unblocking { Task { await service.act("block.remove", ["id": block.id]) } }; unblocking = nil
        }
      } message: { Text("This account can request contact again. Your previous connection will not be restored.") }
      .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Maroon-Social-data") { result in
        switch result { case .success: saved = true; case .failure(let error): service.error = error.localizedDescription }
        document = AccountExportDocument()
      }
  }
}
struct AccountExportDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  var data = Data()
  init(data: Data = Data()) { self.data = data }
  init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
