import Foundation
import CoreImage.CIFilterBuiltins
import Vision

@main struct QRCodeImageChecks {
    static func main() throws {
        var ledger=RewardLedger()
        for challenge in RewardCatalog.all.prefix(50) { ledger.award(challenge.id) }
        let frames=try PointsSyncCode.frames(.init(ledgers:["qianyi":ledger,"zhenyi":ledger]))
        let context=CIContext()
        for text in [frames.first!,frames.last!] {
            let filter=CIFilter.qrCodeGenerator();filter.message=Data(text.utf8);filter.correctionLevel="L"
            let code=filter.outputImage!,bounds=code.extent.insetBy(dx:-5,dy:-5)
            let white=CIImage(color:CIColor.white).cropped(to:bounds)
            let image=code.composited(over:white).transformed(by:CGAffineTransform(scaleX:3,y:3))
            let cg=context.createCGImage(image,from:image.extent)!
            let request=VNDetectBarcodesRequest();request.symbologies=[.qr]
            try VNImageRequestHandler(cgImage:cg).perform([request])
            precondition(request.results?.contains(where:{$0.payloadStringValue == text}) == true)
        }
        print("PASS: rendered multipart QR images decode to the exact payload using Apple Vision.")
    }
}
