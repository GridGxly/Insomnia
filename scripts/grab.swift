// grab X Y W H SECONDS OUTDIR: screenshots of one screen rect, as fast as
// ScreenCaptureKit returns them, for SECONDS. Files are named by the
// milliseconds since the first one, so the timing can be checked.
import Foundation
import ScreenCaptureKit
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
guard a.count == 7, let x = Double(a[1]), let y = Double(a[2]), let w = Double(a[3]), let h = Double(a[4]), let secs = Double(a[5]) else {
    FileHandle.standardError.write("usage: grab X Y W H SECONDS OUTDIR\n".data(using: .utf8)!)
    exit(2)
}
let out = URL(fileURLWithPath: a[6], isDirectory: true)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let rect = CGRect(x: x, y: y, width: w, height: h)

Task {
    var shots: [(Double, CGImage)] = []
    let start = Date()
    while Date().timeIntervalSince(start) < secs {
        do {
            let img = try await SCScreenshotManager.captureImage(in: rect)
            shots.append((Date().timeIntervalSince(start), img))
        } catch {
            FileHandle.standardError.write("capture failed: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }
    for (t, img) in shots {
        let url = out.appendingPathComponent(String(format: "%06d.png", Int(t * 1000)))
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }
    print("\(shots.count) shots in \(String(format: "%.2f", secs)) s, \(shots.first.map { "\($0.1.width)x\($0.1.height)" } ?? "none")")
    exit(0)
}
RunLoop.main.run()
