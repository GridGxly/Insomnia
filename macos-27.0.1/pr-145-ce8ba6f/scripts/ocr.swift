// ocr FILE...: prints the text Vision reads in each PNG, one line per file.
import AppKit
import Vision
for path in CommandLine.arguments.dropFirst() where path != "--fast" {
    guard let image = NSImage(contentsOfFile: path),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("\(path)\t(unreadable)"); continue
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = CommandLine.arguments.contains("--fast") ? .fast : .accurate
    request.usesLanguageCorrection = false
    do { try VNImageRequestHandler(cgImage: cg).perform([request]) } catch { print("\(path)\terror \(error)"); continue }
    let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    print("\(path)\t\(text)")
}
