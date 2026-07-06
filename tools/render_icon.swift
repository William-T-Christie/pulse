// Renders the Pulse app icon: warm paper canvas, graphite instrument arc,
// muted green status dot. Run: swift render_icon.swift <output.png>
import AppKit
import CoreGraphics

let size = 1024.0
let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
    bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

// Canvas
ctx.setFillColor(rgb(0xF4EFE6))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let center = CGPoint(x: size / 2, y: size / 2)
let radius = size * 0.30
let lineWidth = size * 0.055

// 240° arc, opening at the bottom. In CG coordinates (y-up), the gap is
// centered at -90°; arc runs from 210° down through 0° to -30°.
let startAngle = 210.0 * .pi / 180
let endAngle = -30.0 * .pi / 180

// Track
ctx.setStrokeColor(rgb(0x1A1714, 0.10))
ctx.setLineWidth(lineWidth)
ctx.setLineCap(.round)
ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
ctx.strokePath()

// Indicator arc to ~72%
let progressEnd = startAngle - 0.72 * (240.0 * .pi / 180)
ctx.setStrokeColor(rgb(0x45403A))
ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: progressEnd, clockwise: true)
ctx.strokePath()

// Status dot at arc tip
let dotR = size * 0.045
let tip = CGPoint(
    x: center.x + radius * cos(progressEnd),
    y: center.y + radius * sin(progressEnd)
)
ctx.setFillColor(rgb(0x4F7B5E))
ctx.fillEllipse(in: CGRect(x: tip.x - dotR, y: tip.y - dotR, width: dotR * 2, height: dotR * 2))

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("icon written")
