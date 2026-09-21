import SwiftUI

struct CommerceAccessVerificationView: View {
  let isWorking: Bool
  let didFail: Bool
  let onRetry: () -> Void
  let onRestore: () -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(systemName: "checkmark.shield.fill")
        .font(.system(size: 44, weight: .semibold))
        .foregroundStyle(PillieTheme.coral)

      Text(PillieLocalization.string(
        "commerce.access_verification.title",
        table: "Commerce",
        locale: locale
      ))
      .font(.pillieExtraBold(26))
      .foregroundStyle(PillieTheme.textPrimary)
      .multilineTextAlignment(.center)

      Text(PillieLocalization.string(
        didFail
          ? "commerce.access_verification.error"
          : "commerce.access_verification.body",
        table: "Commerce",
        locale: locale
      ))
      .font(.pillieBody())
      .foregroundStyle(PillieTheme.textMuted)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)

      if isWorking {
        ProgressView()
          .tint(PillieTheme.coral)
          .padding(.top, 4)
      } else {
        Button(action: onRetry) {
          Text(PillieLocalization.string(
            "global.action.retry",
            locale: locale
          ))
          .font(.pillie(17, weight: .bold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: PillieTheme.ctaHeight)
          .background(PillieTheme.dark)
          .clipShape(Capsule())
        }
        .accessibilityIdentifier("commerceAccessRetryButton")

        Button {
          onRestore()
        } label: {
          Text(PillieLocalization.string(
            "paywall.action.restore",
            table: "Commerce",
            locale: locale
          ))
          .font(.pillie(15, weight: .semibold))
          .foregroundStyle(PillieTheme.textMuted)
        }
        .accessibilityIdentifier("commerceAccessRestoreButton")
      }

      Spacer()
    }
    .padding(.horizontal, 32)
    .background(PillieTheme.bg.ignoresSafeArea())
    .accessibilityIdentifier("commerceAccessVerification")
  }
}
