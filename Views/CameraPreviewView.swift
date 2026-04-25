import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var cropMode: CaptureManager.CropMode

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.setSession(session)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.updateCropMode(cropMode)
    }
}

// MARK: -

final class CameraPreviewNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var overlayLayer: CAShapeLayer!
    private var currentCropMode: CaptureManager.CropMode = .none

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(previewLayer)

        overlayLayer = CAShapeLayer()
        overlayLayer.fillColor = NSColor.black.withAlphaComponent(0.55).cgColor
        overlayLayer.fillRule = .evenOdd
        layer?.addSublayer(overlayLayer)
    }

    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        overlayLayer.frame = bounds
        CATransaction.commit()
        updateOverlay()
    }

    func updateCropMode(_ mode: CaptureManager.CropMode) {
        currentCropMode = mode
        updateOverlay()
    }

    private func updateOverlay() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let w = bounds.width, h = bounds.height

        switch currentCropMode {
        case .none:
            overlayLayer.path = nil

        case .square:
            let side = min(w, h)
            let crop = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
            overlayLayer.path = maskPath(crop: crop)

        case .vertical:
            let tw = h * 9.0 / 16.0
            if tw <= w {
                let crop = CGRect(x: (w - tw) / 2, y: 0, width: tw, height: h)
                overlayLayer.path = maskPath(crop: crop)
            } else {
                overlayLayer.path = nil
            }
        }
    }

    private func maskPath(crop: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.addRect(bounds)  // outer fill
        path.addRect(crop)    // inner hole (even-odd rule)
        return path
    }
}
