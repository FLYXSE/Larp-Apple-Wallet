import AVFoundation
import SwiftUI
import UIKit

/// Живое превью фронтальной камеры + оверлей детекции лица.
/// Используется на стадии `.faceID`, когда сканирование идёт через `FaceScanner`.
struct FaceScanStageView: View {
    @ObservedObject var scanner: FaceScanner

    /// Превью зеркалится (как в системном Face ID) — X оверлея отражается.
    private let previewIsMirrored = true
    /// Базовая высота блока камеры в шторке.
    private let stageHeight: CGFloat = 280

    @State private var scanLinePosition: CGFloat = -1
    @State private var isConfirmedFlash = false

    var body: some View {
        VStack(spacing: 14) {
            cameraStage
                .frame(height: stageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(scanner.isFacePresent ? 0.35 : 0.12), lineWidth: 1)
                )

            statusText
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                scanLinePosition = 1
            }
        }
        .onChange(of: scanner.isConfirmed) { confirmed in
            guard confirmed else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                isConfirmedFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isConfirmedFlash = false
            }
        }
    }

    // MARK: - Камера

    private var cameraStage: some View {
        GeometryReader { geo in
            ZStack {
                FaceCameraPreview(session: scanner.session, isMirrored: previewIsMirrored)
                    .ignoresSafeArea()

                if isConfirmedFlash {
                    Color.white.opacity(0.22)
                } else if scanner.isConfirmed {
                    Color.clear
                } else if let box = scanner.faceBox, scanner.imageSize.width > 0 {
                    faceBoxOverlay(box: box, viewSize: geo.size)
                } else {
                    idleGuideOverlay(viewSize: geo.size)
                }

                if scanner.status == .running || scanner.status == .requestingAccess {
                    scanLineOverlay(viewSize: geo.size)
                        .opacity(scanner.isFacePresent || scanner.isConfirmed ? 0 : 1)
                }
            }
        }
    }

    /// Рамка лица: маппинг Vision-бокса (normalized, origin низ-лево) в points
    /// с учётом aspect-fill превью и зеркалирования X.
    private func faceBoxOverlay(box: CGRect, viewSize: CGSize) -> some View {
        let rect = mappedFaceRect(box: box, viewSize: viewSize)
        let strokeColor = scanner.isConfirmed ? Color(hex: "30D158") : Color.white
        let corner = max(14, min(rect.width, rect.height) * 0.2)
        let thickness: CGFloat = 2.5

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(strokeColor, lineWidth: scanner.isConfirmed ? 2.5 : 2)
                .padding(1)

            VStack {
                HStack {
                    cornerMark(length: corner, thickness: thickness)
                    Spacer()
                    cornerMark(length: corner, thickness: thickness)
                        .scaleEffect(x: -1, y: 1)
                }
                Spacer()
                HStack {
                    cornerMark(length: corner, thickness: thickness)
                        .scaleEffect(x: 1, y: -1)
                    Spacer()
                    cornerMark(length: corner, thickness: thickness)
                        .scaleEffect(x: -1, y: -1)
                }
            }
            .padding(4)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .animation(.easeOut(duration: 0.18), value: rect)
    }

    /// Уголковая метка в духе FaceIDGlyphView (левый верхний угол).
    private func cornerMark(length: CGFloat, thickness: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.white)
                .frame(width: length, height: thickness)
            Rectangle()
                .fill(Color.white)
                .frame(width: thickness, height: length)
        }
        .frame(width: length, height: length)
    }

    /// Подсказка «куда смотреть» — центральный прямоугольник.
    private func idleGuideOverlay(viewSize: CGSize) -> some View {
        let side = min(viewSize.width * 0.55, viewSize.height * 0.62)
        return RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
            .frame(width: side, height: side * 1.2)
            .position(x: viewSize.width / 2, y: viewSize.height / 2)
    }

    private func scanLineOverlay(viewSize: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color.white.opacity(0.85))
            .frame(width: viewSize.width * 0.55, height: 2)
            .position(
                x: viewSize.width / 2,
                y: viewSize.height / 2 + scanLinePosition * viewSize.height * 0.28
            )
    }

    // MARK: - Статус

    @ViewBuilder
    private var statusText: some View {
        switch scanner.status {
        case .requestingAccess:
            Text("Запрос доступа к камере…")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "A0A0A5"))

        case .running:
            if scanner.isConfirmed {
                Text("Лицо подтверждено")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "30D158"))
            } else if scanner.isFacePresent {
                Text("Лицо в кадре — удерживайте")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
            } else {
                Text("Поместите лицо в рамку")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "A0A0A5"))
            }

        case .denied, .unavailable, .idle:
            Text("Подтвердите лицом")
                .font(.system(size: 15))
                .foregroundColor(.white)
        }
    }

    private var accessibilitySummary: String {
        switch scanner.status {
        case .requestingAccess: return "Идёт запрос доступа к камере для проверки лица"
        case .running where scanner.isConfirmed: return "Лицо подтверждено"
        case .running where scanner.isFacePresent: return "Лицо обнаружено, удерживайте в кадре"
        case .running: return "Поместите лицо в рамку на экране"
        default: return "Подтвердите лицом"
        }
    }

    // MARK: - Геометрия

    /// Aspect-fill + зеркало: Vision origin низ-лево, SwiftUI — верх-лево.
    private func mappedFaceRect(box: CGRect, viewSize: CGSize) -> CGRect {
        let videoW = scanner.imageSize.width
        let videoH = scanner.imageSize.height
        guard videoW > 0, videoH > 0, viewSize.width > 0, viewSize.height > 0 else {
            return .zero
        }

        let scale = max(viewSize.width / videoW, viewSize.height / videoH)
        let scaledW = videoW * scale
        let scaledH = videoH * scale
        let offsetX = (viewSize.width - scaledW) / 2
        let offsetY = (viewSize.height - scaledH) / 2

        let pixelX = box.origin.x * videoW
        let pixelW = box.width * videoW
        let pixelH = box.height * videoH
        let pixelYFromTop = (1 - box.origin.y - box.height) * videoH

        let displayX: CGFloat
        if previewIsMirrored {
            displayX = offsetX + scaledW - (pixelX + pixelW) * scale
        } else {
            displayX = offsetX + pixelX * scale
        }

        let displayY = offsetY + pixelYFromTop * scale
        let displayW = max(20, pixelW * scale)
        let displayH = max(20, pixelH * scale)
        return CGRect(x: displayX, y: displayY, width: displayW, height: displayH)
    }
}

// MARK: - Camera preview

/// `AVCaptureVideoPreviewLayer` через UIViewRepresentable.
/// Сессия управляется `FaceScanner`; превью только показывает её поток.
struct FaceCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool = true

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        init(session: AVCaptureSession) {
            super.init(frame: .zero)
            backgroundColor = .black
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView(session: session)
        applyOrientationAndMirroring(to: view.previewLayer.connection)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        applyOrientationAndMirroring(to: uiView.previewLayer.connection)
    }

    private func applyOrientationAndMirroring(to connection: AVCaptureConnection?) {
        guard let connection = connection else { return }

        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = isMirrored
        }
    }
}
