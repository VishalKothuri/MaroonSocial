import SwiftUI
import PhotosUI
import MaroonCore

struct OrganizationPromotionView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let organizationID:String
  @State private var title=""
  @State private var place=""
  @State private var details=""
  @State private var starts=Date.now.addingTimeInterval(86400)
  @State private var capacity=50
  @State private var poster:MediaAttachment?
  @State private var selectedPhoto:PhotosPickerItem?
  @State private var nonce=UUID().uuidString
  @State private var publishedID:String?
  @State private var posterSaved=false
  @State private var saving=false
  @State private var draftOwner=""
  @State private var preparing=false
  @State private var preview=false
  @State private var closing=false
  @State private var error:String?
  @FocusState private var focus:String?
  private var key:String { "organization-promotion:"+organizationID }
  private var name:String { store.organizations.first{$0.id==organizationID}?.name ?? "Organization" }
  private var hasDraft:Bool { !title.isEmpty || !place.isEmpty || !details.isEmpty || poster != nil || publishedID != nil }
  private var valid:Bool { !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && title.count<=100 && !place.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && place.count<=200 && details.count<=2000 && starts > .now }
  private var draft:Binding<CompositionDraft> {
    Binding(get:{
      var fields=["title":title,"place":place,"starts":String(starts.timeIntervalSince1970),"capacity":String(capacity),"posterSaved":String(posterSaved)]
      if let publishedID{fields["publishedID"]=publishedID}
      return CompositionDraft(text:details,media:poster,fields:fields,nonce:nonce,hasContent:hasDraft)
    },set:{saved in
      title=saved.fields["title"] ?? "";place=saved.fields["place"] ?? "";details=saved.text;poster=saved.media;nonce=saved.nonce
      starts=Date(timeIntervalSince1970:Double(saved.fields["starts"] ?? "") ?? Date.now.addingTimeInterval(86400).timeIntervalSince1970)
      capacity=Int(saved.fields["capacity"] ?? "") ?? 50;publishedID=saved.fields["publishedID"];posterSaved=saved.fields["posterSaved"] == "true"
    })
  }
  var body:some View {
    NavigationStack {
      Form {
        if publishedID != nil { Section { Text("The event is published. Finish its poster upload below; retrying keeps the same event.").font(.caption) } }
        Section("Event or promotion") {
          Text(name).font(.headline)
          TextField("Title",text:$title).focused($focus,equals:"title").accessibilityIdentifier("promotionTitle")
          TextField("Public venue or online meeting place",text:$place).focused($focus,equals:"place").accessibilityIdentifier("promotionPlace")
          DatePicker("When",selection:$starts,in:Date.now...,displayedComponents:[.date,.hourAndMinute])
          Stepper("\(capacity) spots",value:$capacity,in:2...100)
        }.disabled(publishedID != nil || saving)
        Section("About") { TextEditor(text:$details).frame(minHeight:110).focused($focus,equals:"details").accessibilityIdentifier("promotionDetails");Text("\(details.count)/2,000").font(.caption).foregroundStyle(Palette.secondary) }.disabled(publishedID != nil || saving)
        Section("Poster") {
          if let poster { AttachmentPreview(media:poster).frame(maxWidth:.infinity).frame(height:240);Button("Remove poster",role:.destructive){self.poster=nil;selectedPhoto=nil} }
          PhotosPicker(selection:$selectedPhoto,matching:.images){Label(poster == nil ? "Add a poster":"Change poster",systemImage:"photo")}.accessibilityIdentifier("promotionPoster")
          Text("The image appears with your public event. Its location metadata is removed before upload.").font(.caption).foregroundStyle(Palette.secondary)
          if preparing { ProgressView("Preparing poster…") }
        }.disabled(saving || publishedID != nil)
        if let error { Section { Text(error).font(.caption).foregroundStyle(Palette.secondary) } }
        if let error=store.compositions.error { Section { Text(error).font(.caption).foregroundStyle(Palette.secondary) } }
        Section {
          Button(publishedID == nil ? "Preview promotion":"Finish publishing"){focus=nil;if publishedID == nil{preview=true}else{publish()}}
            .buttonStyle(PrimaryButton()).disabled(saving || preparing || (publishedID == nil && !valid)).accessibilityIdentifier("promotionPreview")
        }
      }.scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively).appBackground()
        .navigationTitle("New promotion").navigationBarTitleDisplayMode(.inline).interactiveDismissDisabled(hasDraft || saving)
        .toolbar {
          ToolbarItem(placement:.cancellationAction){Button(publishedID == nil ? "Cancel":"Close"){if hasDraft{closing=true}else{dismiss()}}.disabled(saving)}
          ToolbarItem(placement:.topBarTrailing){if focus != nil {KeyboardDismissButton{focus=nil}}}
        }
        .onAppear { if draftOwner.isEmpty { draftOwner = store.compositions.owner } }
        .persistentDraft(key,value:draft)
        .alert(publishedID == nil ? "Keep this promotion draft?":"Finish the poster later?",isPresented:$closing){
          Button("Save and close"){Task{if await store.compositions.saveDraft(draft.wrappedValue,key:key,owner:draftOwner){dismiss()}}}
          Button(publishedID == nil ? "Discard draft":"Discard unsent poster",role:.destructive){Task{clear();await store.compositions.removeDraft(key,owner:draftOwner);dismiss()}}
          Button("Keep editing",role:.cancel){}
        }message:{Text(publishedID == nil ? "Saved drafts stay on this device.":"Your published event remains visible. Only its unfinished poster draft can be discarded.")}
        .task(id:selectedPhoto){
          guard let selectedPhoto else{return};preparing=true;error=nil
          do { guard let data=try await selectedPhoto.loadTransferable(type:Data.self)else{throw MediaCompression.Failure.unsupported};let value=try await ActivityPlansService.preparePoster(data);guard !Task.isCancelled,self.selectedPhoto==selectedPhoto else{return};poster=value }
          catch{if !Task.isCancelled{self.error=error.localizedDescription}}
          if !Task.isCancelled{preparing=false}
        }
        .sheet(isPresented:$preview){NavigationStack{ScrollView{VStack(alignment:.leading,spacing:16){Label(name,systemImage:"checkmark.seal.fill").font(.headline);Text(title).font(.title2.bold());Text(starts,format:.dateTime.month().day().hour().minute());Label(place,systemImage:"mappin.and.ellipse");if let poster{AttachmentPreview(media:poster).frame(maxWidth:.infinity).frame(height:340)};Text(details);Text("\(capacity) spots · Posted under your organization’s name").font(.caption).foregroundStyle(Palette.secondary);Button(saving ? "Publishing…":"Publish promotion"){publish()}.buttonStyle(PrimaryButton()).disabled(saving).accessibilityIdentifier("promotionPublish");if let error{Text(error).font(.caption).foregroundStyle(Palette.secondary)}}.padding(16)}.appBackground().navigationTitle("Preview").navigationBarTitleDisplayMode(.inline).toolbar{Button("Back to draft"){preview=false}.disabled(saving)}.interactiveDismissDisabled(saving)}}
    }
  }
  private func clear(){title="";place="";details="";poster=nil;selectedPhoto=nil;publishedID=nil;posterSaved=false;nonce=UUID().uuidString}
  private func publish(){
    guard draftOwner == store.compositions.owner,!saving,!preparing,(publishedID != nil || valid)else{return};saving=true;error=nil
    Task {
      do {
        guard await store.compositions.saveDraft(draft.wrappedValue,key:key,owner:draftOwner)else{throw SocialServiceError(error:store.compositions.error ?? "Could not save this draft.",code:"unavailable")}
        let service=ActivityPlansService(social:store.social,fixtureMode:store.fixtureMode)
        if publishedID == nil {let id=try await service.publish(["organization_id":organizationID,"nonce":nonce,"title":title,"place":place,"starts":starts.timeIntervalSince1970,"capacity":capacity,"details":details]);guard draftOwner == store.compositions.owner else{return};publishedID=id;guard await store.compositions.saveDraft(draft.wrappedValue,key:key,owner:draftOwner)else{throw SocialServiceError(error:"The event is published. Its draft could not be saved; keep this screen open and retry.",code:"unavailable")}}
        if let poster,let publishedID,!posterSaved{try await service.savePoster(poster.data,activity:publishedID);guard draftOwner == store.compositions.owner else{return};posterSaved=true}
        await store.refreshAndWait();guard draftOwner == store.compositions.owner else{return};clear();await store.compositions.removeDraft(key,owner:draftOwner);preview=false;saving=false;AppHaptics.shared.play(.success);dismiss()
      }catch{guard draftOwner == store.compositions.owner else{return};self.error=(publishedID == nil ? "":"The event is published; its poster still needs attention. ")+error.localizedDescription;saving=false;AppHaptics.shared.play(.error)}
    }
  }
}
