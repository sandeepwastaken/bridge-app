import Foundation
#if canImport(ARKit) && os(iOS)
import ARKit
#endif

@MainActor
final class HeadTracker: NSObject, ObservableObject {
    struct Sample: Equatable {
        var yaw: Float
        var pitch: Float
        var jawOpen: Float
        var browUp: Float
        var smile: Float
    }

    @Published private(set) var isRunning = false
    var onSample: ((Sample) -> Void)?

    static var isSupported: Bool {
        #if canImport(ARKit) && os(iOS)
        ARFaceTrackingConfiguration.isSupported
        #else
        false
        #endif
    }

    #if canImport(ARKit) && os(iOS)
    private let session = ARSession()
    #endif

    func start() {
        #if canImport(ARKit) && os(iOS)
        guard Self.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        session.delegate = self
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        #endif
    }

    func stop() {
        #if canImport(ARKit) && os(iOS)
        session.pause()
        #endif
        isRunning = false
    }

    nonisolated static func angles(forward: SIMD4<Float>) -> (yaw: Float, pitch: Float) {
        (atan2(forward.x, forward.z), asin(max(-1, min(1, forward.y))))
    }
}

#if canImport(ARKit) && os(iOS)
extension HeadTracker: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.lazy.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else { return }
        let angles = HeadTracker.angles(forward: face.transform.columns.2)
        let shapes = face.blendShapes
        func value(_ key: ARFaceAnchor.BlendShapeLocation) -> Float { shapes[key]?.floatValue ?? 0 }
        let sample = Sample(
            yaw: angles.yaw,
            pitch: angles.pitch,
            jawOpen: value(.jawOpen),
            browUp: value(.browInnerUp),
            smile: (value(.mouthSmileLeft) + value(.mouthSmileRight)) / 2
        )
        Task { @MainActor [weak self] in self?.onSample?(sample) }
    }
}
#endif
