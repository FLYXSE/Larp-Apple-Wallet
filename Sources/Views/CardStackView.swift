import SwiftUI

struct CardStackView: View {
    let cards: [WalletCard]
    let onSelect: (WalletCard) -> Void
    let onEdit: (WalletCard) -> Void

    var body: some View {
        GeometryReader { geo in
            let peek = CardMetrics.peek(forWidth: geo.size.width)
            let width = geo.size.width - CardMetrics.horizontalInset * 2
            let lastHeight = cards.last?.type.cardHeight ?? 220
            let stackHeight = CGFloat(max(cards.count - 1, 0)) * peek + lastHeight

            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .top) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        CardFace(card: card)
                            .offset(y: CGFloat(index) * peek)
                            .zIndex(Double(cards.count - index))
                            .onTapGesture {
                                onSelect(card)
                            }
                            .contextMenu {
                                Button {
                                    onEdit(card)
                                } label: {
                                    Label("Редактировать", systemImage: "pencil")
                                }
                            }
                    }
                }
                .frame(width: width, height: stackHeight, alignment: .top)
                .padding(.horizontal, CardMetrics.horizontalInset)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}
