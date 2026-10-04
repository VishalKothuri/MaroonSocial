import SwiftUI

/// An explicit outline keeps action and completion states visible on dark pages,
/// including disabled buttons that the system otherwise fades into the surface.
struct OutlinedActionStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  var emphasized = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.weight(.semibold))
      .multilineTextAlignment(.center)
      .foregroundStyle(Palette.ink.opacity(isEnabled ? 1 : 0.78))
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, minHeight: 48)
      .background(emphasized && isEnabled ? Palette.maroon : Palette.surface,
                  in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(Palette.ink.opacity(isEnabled ? 0.46 : 0.32), lineWidth: 1)
      }
      .opacity(configuration.isPressed && isEnabled ? 0.82 : 1)
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
