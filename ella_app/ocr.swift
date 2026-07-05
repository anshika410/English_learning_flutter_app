import Cocoa
import Vision

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift ocr.swift <image-path>")
    exit(1)
}

let imagePath = CommandLine.arguments[1]
let url = URL(fileURLWithPath: imagePath)

guard let image = NSImage(contentsOf: url),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Failed to load image.")
    exit(1)
}

let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
let request = VNRecognizeTextRequest { (request, error) in
    if let error = error {
        print("Error recognizing text: \(error)")
        return
    }
    
    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
    
    for observation in observations {
        guard let topCandidate = observation.topCandidates(1).first else { continue }
        print(topCandidate.string)
    }
}
request.recognitionLevel = .accurate

do {
    try requestHandler.perform([request])
} catch {
    print("Failed to perform request: \(error)")
}
