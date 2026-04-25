import SwiftUI
import AVFoundation

// Shared observable updated by RecordingHUDController's scroll event monitor
final class PreviewOpacityModel: ObservableObject {
    @Published var opacity: Double

    init(defaultOpacity: Double) {
        opacity = defaultOpacity
    }
}

struct RecordingPreviewView: View {
    let session: AVCaptureSession
    let cropMode: CaptureManager.CropMode

    @EnvironmentObject var opacityModel: PreviewOpacityModel

    var body: some View {
        CameraPreviewView(session: session, cropMode: cropMode)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(opacityModel.opacity)
            .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
    }
}
