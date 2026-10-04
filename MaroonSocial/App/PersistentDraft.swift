import SwiftUI

private struct PersistentDraft: ViewModifier {
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase
  let key: String
  @Binding var value: CompositionDraft
  @State private var restored = false
  @State private var restoredOwner: String?
  @State private var saveTask: Task<Void, Never>?
  func body(content: Content) -> some View {
    content.onAppear {
      guard !restored else { return }
      if let saved = store.compositions.draft(key) { value = saved }
      restoredOwner = store.compositions.owner
      restored = true
    }.onChange(of: value) { _, snapshot in
      guard restored, restoredOwner == store.compositions.owner else { return }
      saveTask?.cancel()
      let owner = restoredOwner
      saveTask = Task { do { try await Task.sleep(for: .milliseconds(300)); try Task.checkCancellation(); guard owner == store.compositions.owner else { return }; _ = await store.compositions.saveDraft(snapshot,key:key,owner:owner) } catch {} }
    }.onChange(of: scenePhase) { _, phase in if phase != .active { save() } }
      .onDisappear { save() }
  }
  private func save() { guard restored, restoredOwner == store.compositions.owner else { return }; saveTask?.cancel(); let snapshot = value, owner = restoredOwner; Task { guard owner == store.compositions.owner else { return }; _ = await store.compositions.saveDraft(snapshot,key:key,owner:owner) } }
}
extension View {
  func persistentDraft(_ key: String, value: Binding<CompositionDraft>) -> some View { modifier(PersistentDraft(key:key,value:value)) }
}
