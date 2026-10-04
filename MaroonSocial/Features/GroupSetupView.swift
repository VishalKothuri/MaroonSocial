import MaroonCore
import SwiftUI
import UIKit

struct GroupAvatarBadge: View {
  let token: String
  var size: CGFloat = 48
  private var index: Int { GroupFormRules.avatars.firstIndex(of: token) ?? 0 }
  private let symbols = ["bolt.fill", "star.fill", "leaf.fill", "sparkles", "moon.fill", "flame.fill", "mountain.2.fill", "heart.fill"]
  private let colors: [Color] = [Palette.maroon, Color(red: 0.48, green: 0.33, blue: 0.10), Color(red: 0.16, green: 0.36, blue: 0.25), Color(red: 0.12, green: 0.29, blue: 0.46), Color(red: 0.32, green: 0.22, blue: 0.44), Color(red: 0.48, green: 0.23, blue: 0.17), Color(red: 0.24, green: 0.29, blue: 0.35), Color(red: 0.43, green: 0.17, blue: 0.29)]
  var body: some View {
    Image(systemName: symbols[index]).font(.system(size: size * 0.4, weight: .semibold))
      .foregroundStyle(Palette.onAccent).frame(width: size, height: size)
      .background(colors[index], in: RoundedRectangle(cornerRadius: size * 0.28))
      .overlay(RoundedRectangle(cornerRadius: size * 0.28).strokeBorder(Palette.ink.opacity(0.16)))
      .accessibilityHidden(true)
  }
}

struct GroupAvatarPicker: View {
  @Binding var selection: String
  let label: String
  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
      ForEach(GroupFormRules.avatars, id: \.self) { token in
        Button {
          guard selection != token else { return }
          selection = token; AppHaptics.shared.play(.selection)
        } label: {
          GroupAvatarBadge(token: token).padding(4)
            .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(selection == token ? Palette.accentText : .clear, lineWidth: 2))
        }.buttonStyle(.plain).accessibilityLabel("\(label), \(token)")
          .accessibilityAddTraits(selection == token ? .isSelected : [])
          .accessibilityIdentifier("\(label == "Group avatar" ? "groupAvatar" : "groupMemberAvatar")-\(token)")
      }
    }.padding(.vertical, 5)
  }
}

/// Shared by Inbox and Explore; every route creates the same backed group.
struct GroupSetupView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var service: CommunitiesService
  let onCreated: (String) -> Void
  @State private var step = 0
  @State private var movingForward = true
  @State private var choosingAvatar = false
  @State private var groupPhoto: Data?
  @State private var memberPhoto: Data?
  @State private var groupPhotoSaved = false
  @State private var memberPhotoSaved = false
  @State private var purpose = ""
  @State private var name = ""
  @State private var about = ""
  @State private var avatar = "maroon"
  @State private var isPublic = false
  @State private var alias = ""
  @State private var memberAvatar = "gold"
  @State private var usernames = ""
  @State private var sending = false
  @State private var draftOwner = ""
  @State private var nonce = UUID().uuidString
  @State private var creationKey: Data?
  @State private var createdID: String?
  @State private var invited: Set<String> = []
  @State private var failures: [String: String] = [:]
  @State private var error: String?
  @State private var discard = false
  @FocusState private var focused: Field?
  private enum Field: Hashable { case name, about, alias, usernames }
  private let headings = ["Group details", "Your identity", "Invitations"]
  private let stepLabels = ["Details", "Identity", "Invite"]
  private let introductions = ["Make a space for your people.", "Choose how this group will know you.", "Bring people in, or start on your own."]
  init(social: SocialService, fixtureMode: Bool, onCreated: @escaping (String) -> Void) {
    _service = State(initialValue: CommunitiesService(social: social, fixtureMode: fixtureMode)); self.onCreated = onCreated
  }
  private var hasDraft: Bool {
    groupPhoto != nil || memberPhoto != nil || !purpose.isEmpty || !name.isEmpty || !about.isEmpty || !alias.isEmpty || !usernames.isEmpty || avatar != "maroon" || memberAvatar != "gold" || isPublic
  }
  private var savedDraft:Binding<CompositionDraft> {
    Binding(get:{
      var fields=["step":String(step),"purpose":purpose,"name":name,"about":about,"avatar":avatar,"isPublic":String(isPublic),"alias":alias,"memberAvatar":memberAvatar,"usernames":usernames,"groupPhotoSaved":String(groupPhotoSaved),"memberPhotoSaved":String(memberPhotoSaved)]
      if let createdID{fields["createdID"]=createdID}
      if let creationKey{fields["creationKey"]=creationKey.base64EncodedString()}
      fields["invited"]=(try? JSONEncoder().encode(invited.sorted())).flatMap{String(data:$0,encoding:.utf8)}
      fields["failures"]=(try? JSONEncoder().encode(failures)).flatMap{String(data:$0,encoding:.utf8)}
      return CompositionDraft(media:groupPhoto.map{CompositionIdentity.image($0,identity:"group-photo")},additionalMedia:memberPhoto.map{[CompositionIdentity.image($0,identity:"member-photo")]},fields:fields,nonce:nonce,hasContent:hasDraft || createdID != nil)
    },set:{value in
      let f=value.fields;step=min(2,max(0,Int(f["step"] ?? "") ?? 0));purpose=f["purpose"] ?? "";name=f["name"] ?? "";about=f["about"] ?? "";avatar=f["avatar"] ?? "maroon";isPublic=f["isPublic"] == "true";alias=f["alias"] ?? "";memberAvatar=f["memberAvatar"] ?? "gold";usernames=f["usernames"] ?? "";nonce=value.nonce
      createdID=f["createdID"];creationKey=f["creationKey"].flatMap{Data(base64Encoded:$0)}
      invited=Set(f["invited"].flatMap{$0.data(using:.utf8)}.flatMap{try? JSONDecoder().decode([String].self,from:$0)} ?? [])
      failures=f["failures"].flatMap{$0.data(using:.utf8)}.flatMap{try? JSONDecoder().decode([String:String].self,from:$0)} ?? [:]
      groupPhoto=value.media?.data;memberPhoto=value.additionalMedia?.first?.data;groupPhotoSaved=f["groupPhotoSaved"] == "true";memberPhotoSaved=f["memberPhotoSaved"] == "true"
    })
  }
  private func persistDraft()async->Bool {
    guard draftOwner == store.compositions.owner else { return false }
    let saved=await store.compositions.saveDraft(savedDraft.wrappedValue,key:"group-create",owner:draftOwner)
    guard draftOwner == store.compositions.owner else { return false }
    if !saved{error=store.compositions.error ?? "Your group draft could not be saved."}
    return saved
  }
  private func clearDraft(){purpose="";name="";about="";alias="";usernames="";avatar="maroon";memberAvatar="gold";isPublic=false;groupPhoto=nil;memberPhoto=nil;groupPhotoSaved=false;memberPhotoSaved=false;createdID=nil;creationKey=nil;invited=[];failures=[:];nonce=UUID().uuidString;step=0}
  private var groupTitle: String {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return title.isEmpty ? "Your new group" : title
  }
  private var identityTitle: String {
    let title = alias.trimmingCharacters(in: .whitespacesAndNewlines)
    return title.isEmpty ? "Your group alias" : title
  }
  private var readyToOpen: Bool { createdID != nil && failures.isEmpty }
  private var canContinue: Bool {
    switch step {
    case 0:
      return GroupFormRules.purposes.contains(purpose)
        && (3...60).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count)
        && (10...500).contains(about.trimmingCharacters(in: .whitespacesAndNewlines).count)
    case 1: return GroupFormRules.validAlias(alias)
    default: return (try? GroupFormRules.usernames(usernames)) != nil
    }
  }
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        if !dynamicTypeSize.isAccessibilitySize { stepHeader }
        ZStack {
          stepContent.id(step)
            .transition(reduceMotion ? .identity : .asymmetric(
              insertion: .move(edge: movingForward ? .trailing : .leading),
              removal: .move(edge: movingForward ? .leading : .trailing)))
        }.frame(maxHeight: .infinity).clipped()
        footer
      }.appBackground()
        .navigationTitle("New group").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(createdID == nil ? "Cancel" : "Close") {
              focused = nil
              if createdID != nil { Task{if await persistDraft(){dismiss()}} }
              else if hasDraft { AppHaptics.shared.play(.warning); discard = true }
              else { dismiss() }
            }.disabled(sending).accessibilityIdentifier("groupCancel")
          }
          ToolbarItem(placement: .topBarTrailing) {
            if focused != nil { KeyboardDismissButton { focused = nil } }
          }
        }
        .onAppear { if draftOwner.isEmpty { draftOwner = store.compositions.owner } }
        .persistentDraft("group-create",value:savedDraft)
        .interactiveDismissDisabled(hasDraft || sending || createdID != nil)
        .alert("Keep this group draft?", isPresented: $discard) {
          Button("Save and close"){Task{if await persistDraft(){dismiss()}}}
          Button("Discard draft", role: .destructive) { Task{clearDraft();await store.compositions.removeDraft("group-create",owner:draftOwner);dismiss()} }
          Button("Keep editing", role: .cancel) {}
        }
    }
  }
  private var stepHeader: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 8) {
          Text("Step \(step + 1) of 3").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondary)
          HStack(spacing: 6) {
            ForEach(stepLabels.indices, id: \.self) { index in
              Capsule().fill(index <= step ? Palette.ink : Palette.border).frame(height: 4)
            }
          }
        }.accessibilityElement(children: .ignore).accessibilityLabel("Group setup step \(step + 1) of 3")
      } else {
    HStack(spacing: 8) {
      ForEach(stepLabels.indices, id: \.self) { index in
        HStack(spacing: 6) {
          Image(systemName: index < step ? "checkmark.circle.fill" : "\(index + 1).circle\(index == step ? ".fill" : "")")
            .font(.subheadline.weight(.semibold))
          Text(stepLabels[index]).font(.caption.weight(index == step ? .bold : .medium))
        }.foregroundStyle(index <= step ? Palette.ink : Palette.secondary)
          .frame(maxWidth: .infinity, minHeight: 36)
          .background(index == step ? Palette.hero : Palette.surface, in: RoundedRectangle(cornerRadius: 10))
          .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(index == step ? Palette.ink.opacity(0.22) : Color.clear))
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Step \(index + 1) of 3, \(stepLabels[index]), \(index < step ? "complete" : index == step ? "current" : "upcoming")")
      }
    }
      }
    }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
  }
  private var stepContent: some View {
    ScrollViewReader { proxy in
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if dynamicTypeSize.isAccessibilitySize { stepHeader.padding(.horizontal, -16) }
        VStack(alignment: .leading, spacing: 4) {
          Text(headings[step]).font(.title2.bold()).accessibilityIdentifier("groupStepTitle")
          Text(introductions[step]).font(.subheadline).foregroundStyle(Palette.secondary)
        }.padding(.top, 4)
        switch step {
        case 0: detailsFields
        case 1: identityFields
        default: invitationFields
        }
        if let message = error ?? service.error {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.lime).padding(.top, 2)
            Text(message).font(.callout).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("groupSetupError")
          }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 14))
        }
      }.padding(.horizontal, 16).padding(.bottom, 20)
    }.disabled(sending).scrollDismissesKeyboard(.interactively)
      .accessibilityIdentifier("groupSetupForm")
      .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
        // Let the field become first responder and keyboard avoidance settle
        // before moving the scroll view. At large sizes, reveal the complete
        // editor instead of relying only on UIKit's insertion-point avoidance.
        if dynamicTypeSize.isAccessibilitySize, let focused { proxy.scrollTo(focused, anchor: .center) }
      }
    }
  }
  private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12, content: content)
      .frame(maxWidth: .infinity, alignment: .leading).padding(14)
      .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.border.opacity(0.65)))
  }
  private var groupPreview: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        GroupAvatarBadge(token: avatar, size: 52)
        VStack(alignment: .leading, spacing: 5) {
          Text(groupTitle).font(.headline).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("groupPreviewName")
          Label(isPublic ? "Public group" : "Invite only", systemImage: isPublic ? "globe.americas" : "lock.fill")
            .font(.caption).foregroundStyle(Palette.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
        if step == 0 {
          Button {
            AppHaptics.shared.play(.selection)
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { choosingAvatar.toggle() }
          } label: {
            Image(systemName: choosingAvatar ? "chevron.up" : "paintpalette")
              .font(.body.weight(.semibold)).frame(width: 44, height: 44)
              .background(Palette.ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
          }.buttonStyle(.plain).accessibilityLabel("Choose group icon").accessibilityIdentifier("groupEditAvatar")
            .accessibilityValue(choosingAvatar ? "Expanded" : "Collapsed")
        }
      }
      if step == 0 { GroupPhotoPicker(photo: $groupPhoto, label: "Choose group photo") }
      if step == 0 && choosingAvatar {
        Divider()
        GroupAvatarPicker(selection: $avatar, label: "Group avatar")
      }
    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
      .background(LinearGradient(colors: [Palette.hero, Palette.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.ink.opacity(0.12)))
  }
  private var detailsFields: some View {
    Group {
      groupPreview
      card {
        HStack {
          Text("Group name").font(.subheadline.bold())
          Spacer()
          Text("3–60 characters").font(.caption).foregroundStyle(Palette.secondary)
        }
        TextField("Name your group", text: $name).font(.body)
          .focused($focused, equals: .name).submitLabel(.next).onSubmit { focused = .about }
          .padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 10)).accessibilityIdentifier("groupName").id(Field.name)
        HStack {
          Text("Description").font(.subheadline.bold())
          Spacer()
          Text("10–500 characters").font(.caption).foregroundStyle(Palette.secondary)
        }
        TextField("What will people chat about?", text: $about, axis: .vertical)
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1...2 : 2...4).focused($focused, equals: .about)
          .padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 10)).accessibilityIdentifier("groupDescription").id(Field.about)
      }
      VStack(alignment: .leading, spacing: 10) {
        Text("What brings you together?").font(.subheadline.bold())
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 220 : 96), spacing: 8)], spacing: 8) {
          ForEach(GroupFormRules.purposes, id: \.self) { value in
            Button {
              guard purpose != value else { return }
              purpose = value; AppHaptics.shared.play(.selection)
            } label: {
              HStack(spacing: 5) {
                if purpose == value { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                Text(value).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
              }.frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 6)
                .background(purpose == value ? Palette.hero : Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(purpose == value ? Palette.ink.opacity(0.55) : Palette.border, lineWidth: 1))
            }.buttonStyle(.plain).accessibilityIdentifier("groupPurpose-" + value)
              .accessibilityAddTraits(purpose == value ? .isSelected : [])
          }
        }
      }
      VStack(alignment: .leading, spacing: 10) {
        Text("Who can join?").font(.subheadline.bold())
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(alignment: .top, spacing: 8))) {
          visibilityChoice(publicGroup: false, title: "Invite only", detail: "Join with an invitation or a shared code.", icon: "lock.fill")
          visibilityChoice(publicGroup: true, title: "Public", detail: "A&M members can find and join in Explore.", icon: "globe.americas")
        }
        Text("Messages and the member list are visible only after joining.").font(.caption).foregroundStyle(Palette.secondary)
      }
    }
  }
  private func visibilityChoice(publicGroup: Bool, title: String, detail: String, icon: String) -> some View {
    Button {
      guard isPublic != publicGroup else { return }
      isPublic = publicGroup; AppHaptics.shared.play(.selection)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: icon).font(.body.weight(.semibold))
          Spacer()
          Image(systemName: isPublic == publicGroup ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isPublic == publicGroup ? Palette.ink : Palette.secondary)
        }
        Text(title).font(.subheadline.bold())
        Text(detail).font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
      }.frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 0 : 112, alignment: .topLeading)
        .padding(12).background(isPublic == publicGroup ? Palette.hero : Palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isPublic == publicGroup ? Palette.ink.opacity(0.55) : Palette.border))
    }.buttonStyle(.plain).accessibilityIdentifier(publicGroup ? "groupPublic" : "groupInviteOnly")
      .accessibilityAddTraits(isPublic == publicGroup ? .isSelected : [])
  }
  private var identityFields: some View {
    Group {
      card {
        Text("HOW MEMBERS WILL SEE YOU").font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(Palette.secondary)
        HStack(spacing: 12) {
          GroupAvatarBadge(token: memberAvatar, size: 52)
          VStack(alignment: .leading, spacing: 4) {
            Text(identityTitle).font(.headline).accessibilityIdentifier("groupIdentityPreview")
            Text("Group creator · \(groupTitle)").font(.caption).foregroundStyle(Palette.secondary)
          }.fixedSize(horizontal: false, vertical: true)
        }
      }
      card {
        HStack(alignment: .firstTextBaseline) {
          Text("Your alias").font(.subheadline.bold())
          Spacer(minLength: 8)
          Button {
            let identity = GroupFormRules.randomIdentity(); alias = identity.alias; memberAvatar = identity.avatar
            AppHaptics.shared.play(.selection)
          } label: { Label("Shuffle", systemImage: "dice").font(.subheadline.weight(.semibold)).frame(minHeight: 44) }
            .buttonStyle(.plain).accessibilityLabel("Shuffle name & icon").accessibilityIdentifier("groupShuffleIdentity")
        }
        TextField("Choose an alias", text: $alias).textInputAutocapitalization(.never).autocorrectionDisabled()
          .focused($focused, equals: .alias).submitLabel(.next).onSubmit { if canContinue { changeStep(to: 2) } }
          .padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 10)).accessibilityIdentifier("groupAlias").id(Field.alias)
        Text("3–24 letters, numbers, or underscores.").font(.caption).foregroundStyle(Palette.secondary)
        Divider()
        Text("Choose your icon").font(.subheadline.bold())
        GroupAvatarPicker(selection: $memberAvatar, label: "Your avatar")
        GroupPhotoPicker(photo: $memberPhoto, label: "Choose your group photo")
      }
      Label {
        Text("This identity belongs to this group. Your account username stays separate.")
      } icon: { Image(systemName: "person.crop.circle.badge.checkmark") }
        .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
    }
  }
  private var invitationFields: some View {
    Group {
      groupPreview
      card {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())) {
          Text(createdID == nil ? "Account usernames" : "Group created").font(.subheadline.bold())
          if !dynamicTypeSize.isAccessibilitySize { Spacer() }
          if createdID == nil { Text("Optional").font(.caption).foregroundStyle(Palette.secondary) }
        }
        TextField("username_one, username_two", text: $usernames, axis: .vertical)
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1...2 : 2...4)
          .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused, equals: .usernames)
          .padding(12).background(Palette.paper, in: RoundedRectangle(cornerRadius: 10))
          .accessibilityIdentifier("groupInviteUsernames").id(Field.usernames).disabled(readyToOpen)
        if !usernames.isEmpty, let failure = invitationValidation {
          Label(failure, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Palette.ink)
        } else if let people = try? GroupFormRules.usernames(usernames), !people.isEmpty {
          Label("\(people.count) \(people.count == 1 ? "person will receive an invitation" : "people will receive invitations")", systemImage: "person.badge.plus")
            .font(.caption).foregroundStyle(Palette.secondary)
        } else {
          Text("Separate usernames with commas or spaces. Invite up to 20 people.").font(.caption).foregroundStyle(Palette.secondary)
        }
      }
      Label {
        Text("Invitations arrive in Requests. Everyone chooses their own group alias and icon before joining.")
      } icon: { Image(systemName: "envelope") }
        .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
      if !invited.isEmpty {
        card {
          Text("Invitations sent").font(.subheadline.bold())
          ForEach(invited.sorted(), id: \.self) { Text("@" + $0).font(.subheadline) }
        }
      }
      if !failures.isEmpty {
        card {
          Text("Couldn’t invite").font(.subheadline.bold())
          ForEach(failures.keys.sorted(), id: \.self) { username in
            VStack(alignment: .leading, spacing: 3) {
              Text("@" + username).font(.subheadline.bold())
              Text(failures[username] ?? "Please retry.").font(.caption).foregroundStyle(Palette.secondary)
            }
          }
          Text("Your group is saved. Correct these usernames and retry, or invite people from group settings later.").font(.caption).foregroundStyle(Palette.secondary)
        }
      }
      if createdID == nil {
        Button {
          usernames = ""; focused = nil; Task { await createAndInvite() }
        } label: {
          Text("Skip invitations").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.plain).disabled(sending).accessibilityIdentifier("groupSkipInvites")
          .accessibilityHint("Create the group now and invite people later")
      }
    }
  }
  private var invitationValidation: String? {
    do { _ = try GroupFormRules.usernames(usernames); return nil } catch { return error.localizedDescription }
  }
  private var primaryLabel: String {
    if sending { return createdID == nil ? "Creating group…" : "Finishing…" }
    if step == 0 { return "Continue to identity" }
    if step == 1 { return "Continue to invitations" }
    return readyToOpen ? "Open group" : createdID != nil ? "Retry invitations" : "Create group"
  }
  private var footer: some View {
    HStack(spacing: 12) {
      if step > 0 && createdID == nil {
        Button { changeStep(to: step - 1) } label: {
          Image(systemName: "arrow.left").font(.body.weight(.semibold)).frame(width: 50, height: 50)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).disabled(sending).accessibilityLabel("Back").accessibilityIdentifier("groupBack")
      }
      Button {
        focused = nil; error = nil
        if step < 2 { changeStep(to: step + 1) }
        else { Task { await createAndInvite() } }
      } label: {
        HStack(spacing: 10) {
          if sending { ProgressView().tint(Palette.onAccent) }
          Text(dynamicTypeSize.isAccessibilitySize && step < 2 ? "Continue" : primaryLabel).font(.subheadline.bold()).multilineTextAlignment(.center)
          if step < 2 && !dynamicTypeSize.isAccessibilitySize { Image(systemName: "arrow.right").font(.subheadline.weight(.semibold)) }
        }.padding(.horizontal, 12).padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
          .frame(maxWidth: .infinity, minHeight: 50)
          .background(canContinue || readyToOpen ? Palette.maroon : Palette.surface, in: RoundedRectangle(cornerRadius: 14))
          .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.ink.opacity(canContinue || readyToOpen ? 0.12 : 0.05)))
      }.buttonStyle(.plain).foregroundStyle(Palette.onAccent.opacity(canContinue || readyToOpen ? 1 : 0.45))
        .accessibilityLabel(primaryLabel)
        .disabled((!canContinue && !readyToOpen) || sending).accessibilityIdentifier(step == 2 ? "groupCreateSubmit" : "groupContinue")
    }.padding(.horizontal, 16).padding(.vertical, 10).background(Palette.paper)
      .overlay(alignment: .top) { Divider() }
  }
  private func changeStep(to nextStep: Int) {
    guard nextStep != step, (0...2).contains(nextStep), !sending else { return }
    focused = nil; error = nil; service.error = nil; movingForward = nextStep > step
    AppHaptics.shared.play(.impact)
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.28)) { step = nextStep }
  }
  private func createAndInvite() async {
    guard draftOwner == store.compositions.owner, canContinue || readyToOpen, !sending else { return }
    AppHaptics.shared.play(.impact)
    sending = true
    defer { sending = false }
    if readyToOpen { await finish(); return }
    let names: [String]
    do { names = try GroupFormRules.usernames(usernames) }
    catch { self.error = error.localizedDescription; AppHaptics.shared.play(.error); return }
    if createdID == nil {
      var payload: [String: Any] = ["title": name.trimmingCharacters(in: .whitespacesAndNewlines), "description": about.trimmingCharacters(in: .whitespacesAndNewlines), "category": purpose, "is_public": isPublic, "avatar": avatar, "alias": alias.trimmingCharacters(in: .whitespacesAndNewlines), "member_avatar": memberAvatar]
      let key = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
      if key != creationKey { creationKey = key; nonce = UUID().uuidString }
      payload["nonce"] = nonce
      guard await persistDraft()else{return}
      guard let id = await service.act("create", payload), id != "ok" else { AppHaptics.shared.play(.error); return }
      guard draftOwner == store.compositions.owner else { return }
      createdID = id
      guard await persistDraft()else{return}
    }
    guard draftOwner == store.compositions.owner, let id = createdID else { return }
    failures = [:]
    for username in names where !invited.contains(username) {
      guard draftOwner == store.compositions.owner else { return }
      let accepted = await service.act("invite", ["room_id": id, "username": username]) != nil
      guard draftOwner == store.compositions.owner else { return }
      if accepted { invited.insert(username);guard await persistDraft()else{return} }
      else { failures[username] = service.error ?? "This invitation could not be sent." }
    }
    guard await persistDraft()else{return}
    if failures.isEmpty { await finish() }
    else { AppHaptics.shared.play(.warning) }
  }
  private func finish() async {
    guard draftOwner == store.compositions.owner, let id = createdID else { return }
    error = nil
    do {
      let photos = GroupPhotoService(social: store.social, fixtureMode: store.fixtureMode)
      if let groupPhoto, !groupPhotoSaved { try await photos.save(groupPhoto, room: id); guard draftOwner == store.compositions.owner else { return }; groupPhotoSaved = true;guard await persistDraft()else{return} }
      if let memberPhoto, !memberPhotoSaved { try await photos.save(memberPhoto, room: id, memberKey: "self"); guard draftOwner == store.compositions.owner else { return }; memberPhotoSaved = true;guard await persistDraft()else{return} }
    } catch { guard draftOwner == store.compositions.owner else { return }; self.error = "Your group is saved, but its photo could not upload. Retry to finish, or close and update it from group settings. " + error.localizedDescription; return }
    await store.refreshAfterMutation()
    guard !Task.isCancelled, draftOwner == store.compositions.owner else { return }
    guard store.connectionError == nil,
          store.canAccessConversation(id),
          store.conversationMeta[id]?.kind == "group", store.conversationMeta[id]?.canSend == true,
          store.state.conversations.contains(where: { $0.id == id && !$0.request }) else {
      error = "Your group and sent invitations are saved, but the group couldn’t be opened yet. Tap Open group to retry, or close and return from Inbox later."
      AppHaptics.shared.play(.error)
      return
    }
    AppHaptics.shared.play(.success)
    clearDraft();await store.compositions.removeDraft("group-create",owner:draftOwner);dismiss(); onCreated(id)
  }
}

enum GroupIdentityAction {
  case join(String), accept(String), code, profile(String)
  var action: String {
    switch self { case .join: "join"; case .accept: "accept"; case .code: "join_code"; case .profile: "profile" }
  }
  var roomID: String? { switch self { case let .join(id), let .accept(id), let .profile(id): id; case .code: nil } }
  var title: String { switch self { case .join: "Join group"; case .accept: "Accept invitation"; case .code: "Join with a code"; case .profile: "Your group identity" } }
  var submitLabel: String { switch self { case .join, .code: "Join group"; case .accept: "Accept invitation"; case .profile: "Save identity" } }
}

struct GroupIdentityView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var service: CommunitiesService
  let action: GroupIdentityAction
  let groupName: String
  let initialAlias: String
  let initialAvatar: String
  let onCompleted: (String) -> Void
  @State private var alias: String
  @State private var avatar: String
  @State private var code = ""
  @State private var discard = false
  @State private var submitting = false
  @State private var completedID: String?
  @State private var error: String?
  @FocusState private var field: Field?
  private enum Field { case code, alias }
  init(social: SocialService, fixtureMode: Bool, action: GroupIdentityAction, groupName: String = "", initialAlias: String = "", initialAvatar: String = "gold", onCompleted: @escaping (String) -> Void) {
    _service = State(initialValue: CommunitiesService(social: social, fixtureMode: fixtureMode))
    self.action = action; self.groupName = groupName; self.initialAlias = initialAlias; self.initialAvatar = initialAvatar; self.onCompleted = onCompleted
    _alias = State(initialValue: initialAlias); _avatar = State(initialValue: initialAvatar)
  }
  private var hasChanges: Bool { alias != initialAlias || avatar != initialAvatar || !code.isEmpty }
  private var valid: Bool { GroupFormRules.validAlias(alias) && (action.action != "join_code" || code.count == 10) }
  var body: some View {
    NavigationStack { Form {
      if action.action == "join_code" {
        Section("Invite code") {
          TextField("10-character code", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled().focused($field, equals: .code)
            .font(.system(.body, design: .monospaced)).accessibilityIdentifier("communityInviteCode")
            .onChange(of: code) { _, value in code = String(value.uppercased().filter { $0.isHexDigit }.prefix(10)) }
        }.disabled(completedID != nil)
      }
      Section(groupName.isEmpty ? "Your alias in this group" : "Your alias in \(groupName)") {
        HStack(spacing: 12) {
          GroupAvatarBadge(token: avatar)
          TextField("Choose an alias", text: $alias).textInputAutocapitalization(.never).autocorrectionDisabled().focused($field, equals: .alias).accessibilityIdentifier("groupAlias")
        }
        Button("Shuffle name & icon", systemImage: "dice") { let identity = GroupFormRules.randomIdentity(); alias = identity.alias; avatar = identity.avatar }.accessibilityIdentifier("groupShuffleIdentity")
        Text("Use 3–24 letters, numbers, or underscores. Your account username stays separate from the alias members see here.").font(.caption).foregroundStyle(Palette.secondary)
      }.disabled(completedID != nil)
      Section("Your group avatar") { GroupAvatarPicker(selection: $avatar, label: "Your avatar") }.disabled(completedID != nil)
      Section {
        Button(submitting ? "Saving…" : completedID != nil ? (action.action == "profile" ? "Finish" : "Open group") : action.submitLabel) { field = nil; Task { await submit() } }
          .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.borderedProminent).tint(Palette.maroon).foregroundStyle(Palette.onAccent)
          .disabled(!valid || submitting).accessibilityIdentifier(action.action == "join_code" ? "communityCodeJoin" : "groupIdentitySubmit")
        if let error = error ?? service.error { Text(error).font(.callout).foregroundStyle(Palette.accentText).accessibilityIdentifier("groupIdentityError") }
      } footer: { Text(action.action == "profile" ? "Changing this identity updates the name and avatar shown on your messages in this group." : "Accepting gives you access to this group’s messages and member list. You can leave from group settings.") }
    }.disabled(submitting).scrollContentBackground(.hidden).appBackground().scrollDismissesKeyboard(.interactively)
      .navigationTitle(action.title).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(completedID == nil ? "Cancel" : "Close") { field = nil; if hasChanges && completedID == nil { discard = true } else { dismiss() } }.disabled(submitting).accessibilityIdentifier("groupIdentityCancel") }
        ToolbarItem(placement: .topBarTrailing) { if field != nil { KeyboardDismissButton { field = nil } } }
      }.interactiveDismissDisabled(hasChanges || submitting)
      .alert("Discard your group identity changes?", isPresented: $discard) { Button("Discard changes", role: .destructive) { dismiss() }; Button("Keep editing", role: .cancel) {} }
    }
  }
  private func submit() async {
    guard valid, !submitting else { return }
    submitting = true; error = nil
    defer { submitting = false }
    if completedID == nil {
      var payload: [String: Any] = ["alias": alias.trimmingCharacters(in: .whitespacesAndNewlines), "member_avatar": avatar]
      if let id = action.roomID { payload["room_id"] = id } else { payload["invite_code"] = code }
      guard let result = await service.act(action.action, payload), let id = result == "ok" ? action.roomID : result else { return }
      completedID = id
    }
    guard let id = completedID else { return }
    await store.refreshAfterMutation()
    guard !Task.isCancelled else { return }
    guard store.connectionError == nil,
          store.canAccessConversation(id),
          store.conversationMeta[id]?.kind == "group",
          action.action == "profile" || store.conversationMeta[id]?.canSend == true,
          store.state.conversations.contains(where: { $0.id == id && !$0.request }) else {
      error = "Your group identity is saved, but the group couldn’t be loaded yet. Retry to open it."
      return
    }
    dismiss(); onCompleted(id)
  }
}

struct GroupInviteView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var service: CommunitiesService
  let roomID: String
  @State private var username = ""
  @State private var sent: [String] = []
  @FocusState private var focused: Bool
  init(social: SocialService, fixtureMode: Bool, roomID: String) {
    _service = State(initialValue: CommunitiesService(social: social, fixtureMode: fixtureMode)); self.roomID = roomID
  }
  private var target: String? { guard let values = try? GroupFormRules.usernames(username), values.count == 1 else { return nil }; return values[0] }
  var body: some View {
    NavigationStack { Form {
      Section("Invite by account username") {
        TextField("Account username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused).accessibilityIdentifier("groupInviteUsername")
        Text("Their invitation appears in Requests. They choose a separate group alias and avatar before joining.").font(.caption).foregroundStyle(Palette.secondary)
        Button("Send invitation") {
          guard let target else { return }; focused = false
          Task { if await service.act("invite", ["room_id": roomID, "username": target]) != nil { if !sent.contains(target) { sent.append(target) }; username = "" } }
        }.disabled(target == nil || service.busy).accessibilityIdentifier("groupSendInvite")
        if let error = service.error { Text(error).font(.callout).foregroundStyle(Palette.accentText).accessibilityIdentifier("groupInviteError") }
      }
      if !sent.isEmpty { Section("Invitations sent") { ForEach(sent, id: \.self) { Text("@" + $0) } } }
    }.disabled(service.busy).scrollContentBackground(.hidden).appBackground().scrollDismissesKeyboard(.interactively).navigationTitle("Invite people").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Close") { focused = false; dismiss() }.disabled(service.busy) }
        ToolbarItem(placement: .topBarTrailing) { if focused { KeyboardDismissButton { focused = false } } }
      }
    }
  }
}
