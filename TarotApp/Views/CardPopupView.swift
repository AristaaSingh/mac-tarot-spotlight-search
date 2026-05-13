import SwiftUI

struct CardPopupView: View {
    let card: TarotCard
    var onClose: () -> Void
    var onReversedChange: (Bool) -> Void = { _ in }

    @State private var isReversed = false
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardImage
            closeButton
        }
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    private var cardImage: some View {
        Group {
            if let img = card.image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.1, green: 0.07, blue: 0.2))
                    VStack(spacing: 12) {
                        Text(card.suitSymbol).font(.system(size: 64))
                        Text(card.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .rotationEffect(.degrees(isReversed ? 180 : 0))
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: isReversed)
        .onTapGesture {
            isReversed.toggle()
            onReversedChange(isReversed)
        }
        .help(isReversed ? "Reversed — tap to restore upright" : "Upright — tap to reverse")
    }

    private var closeButton: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 26, height: 26)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .padding(10)
    }
}
