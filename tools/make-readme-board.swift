import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("usage: swift make-readme-board.swift output.png screen1.png [screen2.png ...]")
    exit(1)
}
let output = URL(fileURLWithPath: arguments[1])
let screens = arguments.dropFirst(2).compactMap { NSImage(contentsOfFile: $0) }
guard screens.count == arguments.count - 2, !screens.isEmpty else {
    print("could not read every screenshot")
    exit(1)
}

let canvas = CGSize(width: 2304, height: 1536)
let count = CGFloat(screens.count)
let screenAspect = screens[0].size.height / screens[0].size.width
let gap: CGFloat = count > 3 ? 56 : 90
let phoneWidth = min((1400 / screenAspect).rounded(), ((canvas.width - (count + 1) * gap) / count).rounded())
let phoneHeight = (phoneWidth * screenAspect).rounded()
let totalWidth = count * phoneWidth + (count - 1) * gap
let bezel: CGFloat = 16
let outerRadius = phoneWidth * 0.155

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = canvas
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let context = NSGraphicsContext.current!.cgContext
context.interpolationQuality = .high

let background = NSGradient(colors: [color(0xD3E3EE), color(0xC4D8E6), color(0xD8E2F2)],
                            atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
background.draw(in: CGRect(origin: .zero, size: canvas), angle: -60)

for (index, screen) in screens.enumerated() {
    let x = (canvas.width - totalWidth) / 2 + CGFloat(index) * (phoneWidth + gap)
    let y = (canvas.height - phoneHeight) / 2
    let outer = CGRect(x: x, y: y, width: phoneWidth, height: phoneHeight)
    let outerPath = NSBezierPath(roundedRect: outer, xRadius: outerRadius, yRadius: outerRadius)

    context.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x1F3A5F, 0.22)
    shadow.shadowBlurRadius = 70
    shadow.shadowOffset = NSSize(width: 0, height: -28)
    shadow.set()
    color(0xFBFDFF).setFill()
    outerPath.fill()
    context.restoreGState()

    color(0xFFFFFF).setFill()
    outerPath.fill()
    color(0xDCE5EE).setStroke()
    outerPath.lineWidth = 2
    outerPath.stroke()

    let inner = outer.insetBy(dx: bezel, dy: bezel)
    let innerRadius = outerRadius - bezel
    context.saveGState()
    NSBezierPath(roundedRect: inner, xRadius: innerRadius, yRadius: innerRadius).addClip()
    screen.draw(in: inner, from: .zero, operation: .sourceOver, fraction: 1)
    context.restoreGState()

    let islandWidth = inner.width * 0.3
    let islandHeight = inner.width * 0.088
    let island = CGRect(x: inner.midX - islandWidth / 2, y: inner.maxY - inner.width * 0.035 - islandHeight,
                        width: islandWidth, height: islandHeight)
    color(0x050505).setFill()
    NSBezierPath(roundedRect: island, xRadius: islandHeight / 2, yRadius: islandHeight / 2).fill()
}

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    print("could not encode PNG")
    exit(1)
}
try png.write(to: output)
print("wrote \(output.path) \(Int(canvas.width))x\(Int(canvas.height))")
