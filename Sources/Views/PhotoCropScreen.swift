import SwiftUI
import UIKit

/// Экран обрезки обложки: карточный кроп 1.586:1, pinch-zoom и pan.
struct PhotoCropScreen: View {
    let source: UIImage
    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let aspectRatio: CGFloat = 1.586

    var body: some View {
        GeometryReader { geo in
            let cropWidth = geo.size.width - 32
            let cropHeight = cropWidth / aspectRatio
            let cropSize = CGSize(width: cropWidth, height: cropHeight)
            let cropRect = CGRect(
                x: (geo.size.width - cropWidth) / 2,
                y: (geo.size.height - cropHeight) / 2,
                width: cropWidth,
                height: cropHeight
            )
            let displaySize = imageDisplaySize(cropSize: cropSize)

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: source)
                    .resizable()
                    .scaledToFit()
                    .frame(width: displaySize.width, height: displaySize.height)
                    .offset(offset)

                dimmingOverlay(cropRect: cropRect, canvas: geo.size)

                VStack(spacing: 0) {
                    topBar(cropSize: cropSize)
                    Spacer(minLength: 0)
                    Text("Потяните и масштабируйте, чтобы выровнять кадр")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "A0A0A5"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .simultaneousGesture(dragGesture(cropSize: cropSize))
            .simultaneousGesture(magnificationGesture(cropSize: cropSize))
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Панели

    private func topBar(cropSize: CGSize) -> some View {
        HStack(spacing: 12) {
            Button("Отмена") {
                onCancel()
            }
            .foregroundColor(Color(hex: "0A84FF"))
            .accessibilityLabel("Отменить обрезку")

            Spacer(minLength: 8)

            Text("Обложка")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 8)

            Button("Готово") {
                finish(cropSize: cropSize)
            }
            .fontWeight(.semibold)
            .foregroundColor(Color(hex: "0A84FF"))
            .accessibilityLabel("Применить обрезку")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func dimmingOverlay(cropRect: CGRect, canvas: CGSize) -> some View {
        ZStack {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: canvas))
                path.addRoundedRect(
                    in: cropRect,
                    cornerSize: CGSize(width: CardMetrics.cornerRadius, height: CardMetrics.cornerRadius)
                )
            }
            .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))

            RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
        }
    }

    // MARK: - Геометрия

    private func baseScale(cropSize: CGSize) -> CGFloat {
        guard source.size.width > 0, source.size.height > 0 else { return 1 }
        return max(cropSize.width / source.size.width, cropSize.height / source.size.height)
    }

    private func imageDisplaySize(cropSize: CGSize) -> CGSize {
        let factor = baseScale(cropSize: cropSize) * scale
        return CGSize(
            width: source.size.width * factor,
            height: source.size.height * factor
        )
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 4)
    }

    private func clampOffset(cropSize: CGSize) {
        let display = imageDisplaySize(cropSize: cropSize)
        let limitX = max((display.width - cropSize.width) / 2, 0)
        let limitY = max((display.height - cropSize.height) / 2, 0)

        var clamped = offset
        clamped.width = min(max(clamped.width, -limitX), limitX)
        clamped.height = min(max(clamped.height, -limitY), limitY)

        if clamped != offset {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                offset = clamped
                lastOffset = clamped
            }
        }
    }

    // MARK: - Жесты

    private func magnificationGesture(cropSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = clampedScale(lastScale * value)
            }
            .onEnded { _ in
                lastScale = scale
                clampOffset(cropSize: cropSize)
            }
    }

    private func dragGesture(cropSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                clampOffset(cropSize: cropSize)
            }
    }

    // MARK: - Результат

    private func finish(cropSize: CGSize) {
        let base = baseScale(cropSize: cropSize)
        let factor = base * scale
        guard factor > 0, source.size.width > 0, source.size.height > 0 else {
            onCancel()
            return
        }

        let displayWidth = source.size.width * factor
        let displayHeight = source.size.height * factor

        let originX = (displayWidth / 2 - cropSize.width / 2 - offset.x) / factor
        let originY = (displayHeight / 2 - cropSize.height / 2 - offset.y) / factor

        let cropInPoints = CGRect(
            x: originX,
            y: originY,
            width: cropSize.width / factor,
            height: cropSize.height / factor
        )

        guard let cgImage = source.cgImage else {
            onDone(source)
            return
        }

        var cropInPixels = CGRect(
            x: cropInPoints.origin.x * source.scale,
            y: cropInPoints.origin.y * source.scale,
            width: cropInPoints.size.width * source.scale,
            height: cropInPoints.size.height * source.scale
        )
        cropInPixels = cropInPixels.intersection(
            CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        )

        guard !cropInPixels.isNull,
              cropInPixels.width > 1,
              cropInPixels.height > 1,
              let cropped = cgImage.cropping(to: cropInPixels) else {
            onDone(source)
            return
        }

        onDone(UIImage(cgImage: cropped, scale: source.scale, orientation: .up))
    }
}
