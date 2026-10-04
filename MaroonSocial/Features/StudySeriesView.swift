import SwiftUI

struct StudySeriesView: View {
  @Environment(AppStore.self) private var store
  let activityID:String
  @State private var info:StudySeriesInfo?
  @State private var error:String?
  @State private var cancelling=false
  @State private var busy=false
  var body:some View {
    Group {
      if let info,info.isSeries {
        Card { VStack(alignment:.leading,spacing:10) {
          Label("Weekly study meetings",systemImage:"calendar.badge.clock").font(.headline)
          Text("Join each meeting you plan to attend. Times are in your device’s time zone.").font(.caption).foregroundStyle(Palette.secondary)
          ForEach(info.occurrences ?? []) { occurrence in
            HStack { Text(occurrence.starts,format:.dateTime.month(.abbreviated).day().hour().minute());Spacer();if occurrence.cancelled { Text("Cancelled").foregroundStyle(Palette.secondary) } }.font(.caption)
          }
          if info.canManage == true,(info.occurrences ?? []).contains(where:{!$0.cancelled && $0.starts > .now}) {
            Button("Cancel all future meetings",role:.destructive){cancelling=true}.disabled(busy).accessibilityIdentifier("cancelStudySeries")
          }
        } }
      }
      if let error { VStack(alignment:.leading) { Text(error).font(.caption);Button("Retry series details"){Task{await load()}} }.foregroundStyle(Palette.secondary) }
    }.task(id:activityID){await load()}
      .confirmationDialog("Cancel every future meeting in this series?",isPresented:$cancelling,titleVisibility:.visible){Button("Cancel future meetings",role:.destructive){Task{await load(cancel:true)}}}message:{Text("Each meeting chat will close. Past meetings are kept.")}
  }
  private func load(cancel:Bool=false)async {
    guard !store.fixtureMode,!busy else{return};busy=true;defer{busy=false};error=nil
    do{info=try await ActivityPlansService(social:store.social,fixtureMode:false).series(activity:activityID,cancelFuture:cancel);if cancel{await store.refreshAndWait()}}
    catch{self.error=error.localizedDescription}
  }
}

struct OrganizationPosterView:View {
  @Environment(AppStore.self)private var store
  let activityID:String
  @State private var photo:UIImage?
  @State private var error:String?
  var body:some View {
    Group{
      if let photo{Image(uiImage:photo).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius:16)).accessibilityLabel("Organization event poster")}
      if let error{VStack{Text(error).font(.caption);Button("Retry poster"){Task{await load()}}}.foregroundStyle(Palette.secondary)}
    }.task(id:activityID){await load()}
  }
  private func load()async {
    guard !store.fixtureMode else{return};error=nil
    do{let data=try await ActivityPlansService(social:store.social,fixtureMode:false).poster(activity:activityID);guard !Task.isCancelled else{return};photo=data.flatMap{UIImage(data:$0)}}catch{if !Task.isCancelled{self.error=error.localizedDescription}}
  }
}
