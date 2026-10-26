import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments[1]
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

ctx.setFillColor(rgb(0x00756C))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

func bubble(_ rect: CGRect) -> CGPath {
    let p = CGMutablePath()
    p.addRoundedRect(in: rect, cornerWidth: 96, cornerHeight: 96)
    let tail = CGMutablePath()
    tail.move(to: CGPoint(x: rect.minX + 120, y: rect.minY + 40))
    tail.addLine(to: CGPoint(x: rect.minX + 84, y: rect.minY - 104))
    tail.addLine(to: CGPoint(x: rect.minX + 300, y: rect.minY + 40))
    tail.closeSubpath()
    p.addPath(tail)
    return p
}

let w: CGFloat = 620, h: CGFloat = 236, gap: CGFloat = 56
let lower = CGRect(x: (size - w) / 2, y: size / 2 - gap / 2 - h, width: w, height: h)
ctx.setFillColor(rgb(0xFFFFFF))
ctx.addPath(bubble(lower)); ctx.fillPath()
ctx.saveGState()
ctx.translateBy(x: size / 2, y: size / 2)
ctx.rotate(by: .pi)
ctx.translateBy(x: -size / 2, y: -size / 2)
ctx.setFillColor(rgb(0x9FEBE2))
ctx.addPath(bubble(lower)); ctx.fillPath()
ctx.restoreGState()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
