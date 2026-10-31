import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func draw(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: Double(size) / 1024, y: Double(size) / 1024)
    let body = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 216, yRadius: 216)
    NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.22, alpha: 1).setFill(); body.fill()
    let keyboard = NSBezierPath(roundedRect: NSRect(x: 142, y: 327, width: 740, height: 362), xRadius: 43, yRadius: 43)
    NSColor(calibratedRed: 0.19, green: 0.27, blue: 0.37, alpha: 1).setFill(); keyboard.fill()
    for row in 0..<4 {
        for column in 0..<11 {
            let key = NSBezierPath(roundedRect: NSRect(x: 174 + column * 62, y: 389 + row * 66, width: 48, height: 47), xRadius: 8, yRadius: 8)
            NSColor(calibratedRed: 0.83, green: 0.9, blue: 0.98, alpha: row == 0 ? 0.6 : 0.9).setFill(); key.fill()
        }
    }
    let bar = NSBezierPath(roundedRect: NSRect(x: 174, y: 351, width: 676, height: 14), xRadius: 7, yRadius: 7)
    NSGradient(colors: [NSColor.systemCyan, .systemBlue, .systemPurple, .systemPink])!.draw(in: bar, angle: 0)
    let text: NSString = "51"
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 100, weight: .semibold), .foregroundColor: NSColor.white]
    let width = text.size(withAttributes: attributes).width
    text.draw(at: NSPoint(x: (1024 - width) / 2, y: 182), withAttributes: attributes)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
        try draw(size: points * scale).write(to: output.appendingPathComponent(name))
    }
}
