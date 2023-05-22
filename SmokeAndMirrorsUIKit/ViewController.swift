import UIKit

func setupFace(
    layer: CALayer,
    size: CGFloat,
    baseTransform: CATransform3D,
    face: CubeFace,
    textured: Bool
) {
    layer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: size, height: size))
    layer.isDoubleSided = textured
    layer.transform = face.transform(size: size, baseTransform: baseTransform)
    
    if textured {
        layer.contents = face.texture()?.cgImage
    } else {
        layer.backgroundColor = face.color().cgColor
    }
}

enum CubeFace: CaseIterable {
    case front
    case back
    case left
    case right
    case top
    case bottom
    
    func translationAndRotation(size: CGFloat) -> (translation: (x: CGFloat, y: CGFloat, z: CGFloat), rotation: (angle: CGFloat, x: CGFloat, y: CGFloat, z: CGFloat)) {
        switch self {
        case .front:
            return ((0.0, 0.0, size * 0.5), (0.0, 0.0, 1.0, 0.0))
        case .back:
            return ((0.0, 0.0, -size * 0.5), (-.pi, 0.0, 1.0, 0.0))
        case .left:
            return ((-size * 0.5, 0.0, 0.0), (-.pi * 0.5, 0.0, 1.0, 0.0))
        case .right:
            return ((size * 0.5, 0.0, 0.0), (.pi * 0.5, 0.0, 1.0, 0.0))
        case .top:
            return ((0.0, -size * 0.5, 0.0), (.pi * 0.5, 1.0, 0.0, 0.0))
        case .bottom:
            return ((0.0, size * 0.5, 0.0), (-.pi * 0.5, 1.0, 0.0, 0.0))
        }
    }
    
    func transform(size: CGFloat, baseTransform: CATransform3D) -> CATransform3D {
        let (translation, rotation) = self.translationAndRotation(size: size)
        var transform = baseTransform
        transform = CATransform3DTranslate(transform, translation.x, translation.y, translation.z)
        transform = CATransform3DRotate(transform, rotation.angle, rotation.x, rotation.y, rotation.z)
        return transform
    }
    
    func texture() -> UIImage? {
        let name: String
        switch self {
        case .front:
            name = "front"
        case .back:
            name = "back"
        case .left:
            name = "left"
        case .right:
            name = "right"
        case .top:
            name = "up"
        case .bottom:
            name = "down"
        }
        return UIImage(named: name)
    }
    
    func color() -> UIColor {
        switch self {
        case .front:
            return .blue
        case .back:
            return .yellow
        case .left:
            return .green
        case .right:
            return .cyan
        case .top:
            return .magenta
        case .bottom:
            return .gray
        }
    }
}

func transposeMatrix(_ value: CATransform3D) -> CATransform3D {
    var result = CATransform3DIdentity
    
    var value = value
    var t1Array: [CGFloat] = Array(repeating: 0.0, count: 16)
    t1Array.withUnsafeMutableBytes { buffer in
        let bytes = buffer.baseAddress!.assumingMemoryBound(to: CGFloat.self)
        withUnsafeBytes(of: &value, { sourceBuffer in
            let sourceBytes = sourceBuffer.baseAddress!.assumingMemoryBound(to: CGFloat.self)
            memcpy(bytes, sourceBytes, 16 * MemoryLayout<CGFloat>.size)
        })
    }
    
    var resultArray: [CGFloat] = Array(repeating: 0.0, count: 16)
    
    for i in 0 ..< 4 {
        for j in 0 ..< 4 {
            resultArray[i * 4 + j] = t1Array[j * 4 + i]
        }
    }
    
    resultArray.withUnsafeBytes { buffer in
        let bytes = buffer.baseAddress!.assumingMemoryBound(to: CGFloat.self)
        withUnsafeMutableBytes(of: &result, { sourceBuffer in
            let sourceBytes = sourceBuffer.baseAddress!.assumingMemoryBound(to: CGFloat.self)
            memcpy(sourceBytes, bytes, 16 * MemoryLayout<CGFloat>.size)
        })
    }
    
    return result
}

struct Vector4D {
    var x: Double
    var y: Double
    var z: Double
    var w: Double

    func transformed(with transform: CATransform3D) -> Vector4D {
        let newX = x * Double(transform.m11) + y * Double(transform.m21) + z * Double(transform.m31) + w * Double(transform.m41)
        let newY = x * Double(transform.m12) + y * Double(transform.m22) + z * Double(transform.m32) + w * Double(transform.m42)
        let newZ = x * Double(transform.m13) + y * Double(transform.m23) + z * Double(transform.m33) + w * Double(transform.m43)
        let newW = x * Double(transform.m14) + y * Double(transform.m24) + z * Double(transform.m34) + w * Double(transform.m44)

        return Vector4D(x: newX, y: newY, z: newZ, w: newW)
    }
    
    func normalized() -> Vector4D {
        let norm = sqrt(x * x + y * y + z * z)
        return Vector4D(x: self.x / norm, y: self.y / norm, z: self.z / norm, w: self.w)
    }
    
    func dot(_ other: Vector4D) -> CGFloat {
        return self.x * other.x + self.y * other.y + self.z * other.z
    }
}

func applyTransform(transform: CATransform3D, point: CGPoint) -> CGPoint {
    // Convert the CGPoint to a vector in homogeneous coordinates
    let vector = Vector4D(x: Double(point.x), y: Double(point.y), z: 0.0, w: 1.0)
    
    // Apply the CATransform3D to the vector
    let transformedVector = vector.transformed(with: transform)
    
    // Convert the transformed vector back to CGPoint
    let transformedPoint = CGPoint(x: CGFloat(transformedVector.x / transformedVector.w),
                                   y: CGFloat(transformedVector.y / transformedVector.w))
    
    return transformedPoint
}

func applyTransform(transform: CATransform3D, point: Vector4D) -> Vector4D {
    // Convert the CGPoint to a vector in homogeneous coordinates
    let vector = point
    
    // Apply the CATransform3D to the vector
    let transformedVector = vector.transformed(with: transform)
    
    return Vector4D(x: transformedVector.x / transformedVector.w, y: transformedVector.y / transformedVector.w, z: transformedVector.z / transformedVector.w, w: 1.0)
}

func mirrorMatrix(planePoint: Vector4D, planeTransform: CATransform3D, planeNormal: Vector4D) -> CATransform3D {
    let pt = applyTransform(transform: planeTransform, point: planePoint)
    
    let normalTransform = CATransform3DInvert(planeTransform).transposed
    let normal = applyTransform(transform: normalTransform, point: planeNormal).normalized()
    
    let a = normal.x
    let b = normal.y
    let c = normal.z
    let d = -(a * pt.x + b * pt.y + c * pt.z)
    
    return CATransform3D([
        1 - 2 * a * a, -2 * a * b, -2 * a * c, -2 * a * d,
        -2 * a * b, 1 - 2 * b * b, -2 * b * c, -2 * b * d,
        -2 * a * c, -2 * b * c, 1 - 2 * c * c, -2 * c * d,
        0.0, 0.0, 0.0, 1.0
    ]).transposed
}

public extension CATransform3D {
    init(_ values: [CGFloat]) {
        precondition(values.count == 16)
        
        self = CATransform3DIdentity
        
        values.withUnsafeBytes { buffer in
            let bytes = buffer.baseAddress!.assumingMemoryBound(to: CGFloat.self)
            withUnsafeMutableBytes(of: &self, { sourceBuffer in
                let sourceBytes = sourceBuffer.baseAddress!.assumingMemoryBound(to: CGFloat.self)
                memcpy(sourceBytes, bytes, 16 * MemoryLayout<CGFloat>.size)
            })
        }
    }
    
    var asArray: [CGFloat] {
        var value = self
        var result: [CGFloat] = Array(repeating: 0.0, count: 16)
        result.withUnsafeMutableBytes { buffer in
            let bytes = buffer.baseAddress!.assumingMemoryBound(to: CGFloat.self)
            withUnsafeBytes(of: &value, { sourceBuffer in
                let sourceBytes = sourceBuffer.baseAddress!.assumingMemoryBound(to: CGFloat.self)
                memcpy(bytes, sourceBytes, 16 * MemoryLayout<CGFloat>.size)
            })
        }
        return result
    }
    
    var transposed: CATransform3D {
        let source = self.asArray
        var result = Array<CGFloat>(repeating: 0.0, count: 16)
        
        for i in 0 ..< 4 {
            for j in 0 ..< 4 {
                result[i * 4 + j] = source[j * 4 + i]
            }
        }
        
        return CATransform3D(result)
    }
}

public extension CATransform3D {
    static func perspectiveProjection() -> CATransform3D {
        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 500.0
        return perspective
    }
}

public func *(lhs: CATransform3D, rhs: CATransform3D) -> CATransform3D {
    return CATransform3DConcat(lhs, rhs)
}

func setupCube(
    view: UIView,
    size: CGFloat,
    textured: Bool,
    baseTransform: CATransform3D,
    faces: [CubeFace],
    mirrorFace: CubeFace? = nil
) -> CATransformLayer {
    let cubeLayer = CATransformLayer()
    cubeLayer.position = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    
    for face in faces {
        let faceLayer = CALayer()
        setupFace(layer: faceLayer, size: size, baseTransform: baseTransform, face: face, textured: textured)
        cubeLayer.addSublayer(faceLayer)
    }
    
    if let mirrorFace {
        let mirrorPlane = mirrorFace.transform(size: size, baseTransform: baseTransform)
        let mirror = mirrorMatrix(planePoint: Vector4D(x: 0.0, y: 0.0, z: 0.0, w: 1.0), planeTransform: mirrorPlane, planeNormal: Vector4D(x: 0.0, y: 0.0, z: 1.0, w: 1.0))
        cubeLayer.sublayerTransform = mirror
    }
    
    return cubeLayer
}

func setupReflectiveFace(
    view: UIView,
    size: CGFloat,
    baseTransform: CATransform3D,
    face: CubeFace
) -> CALayer {
    let maskLayer = CALayer()
    maskLayer.frame = view.bounds
    maskLayer.addSublayer(setupCube(view: view, size: size, textured: false, baseTransform: baseTransform, faces: [face]))
    
    let colorLayer = CALayer()
    colorLayer.frame = view.bounds
    colorLayer.mask = maskLayer
    colorLayer.addSublayer(setupCube(view: view, size: 2000.0, textured: true, baseTransform: baseTransform, faces: [.front, .back, .left, .right, .top, .bottom], mirrorFace: face))
    
    return colorLayer
}

class ViewController: UIViewController {
    override func viewDidLoad() {
        var baseTransform = CATransform3DIdentity
        baseTransform.m34 = -1.0 / 400.0
        baseTransform = CATransform3DRotate(baseTransform, 0.5, 0.0, 1.0, 0.0)
        
        for face in CubeFace.allCases {
            view.layer.addSublayer(setupReflectiveFace(view: view, size: 100.0, baseTransform: baseTransform, face: face))
        }
        
        super.viewDidLoad()
    }
}
