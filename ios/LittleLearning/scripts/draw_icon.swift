import Foundation
import CoreGraphics
import ImageIO

// Draw directly into the export bitmap: no offscreen NSImage focus/cache is involved.
let path = CommandLine.arguments[1]
let context = CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:4096,
                        space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ rgb: UInt32) -> CGColor {
    CGColor(red:Double((rgb >> 16) & 255)/255,green:Double((rgb >> 8) & 255)/255,blue:Double(rgb & 255)/255,alpha:1)
}
func rounded(_ rect: CGRect,_ radius: CGFloat,_ rgb: UInt32) {
    context.setFillColor(color(rgb));context.addPath(CGPath(roundedRect:rect,cornerWidth:radius,cornerHeight:radius,transform:nil));context.fillPath()
}
func oval(_ rect: CGRect,_ rgb: UInt32) {
    context.setFillColor(color(rgb));context.fillEllipse(in:rect)
}
context.setFillColor(color(0xF7F2EA));context.fill(CGRect(x:0,y:0,width:1024,height:1024))
rounded(CGRect(x:88,y:122,width:848,height:744),170,0xC9BFA8)
rounded(CGRect(x:88,y:152,width:848,height:744),170,0xFBF8F1)
oval(CGRect(x:190,y:230,width:644,height:360),0x355940)
oval(CGRect(x:190,y:250,width:644,height:360),0x4A7C59)
oval(CGRect(x:310,y:370,width:400,height:280),0xE6AA38)
oval(CGRect(x:624,y:610,width:135,height:60),0xC87A3E)
oval(CGRect(x:480,y:565,width:230,height:230),0xE6AA38)
oval(CGRect(x:620,y:685,width:23,height:23),0x3E2723)
oval(CGRect(x:347,y:414,width:185,height:126),0xB37F1E)
let image = context.makeImage()!
let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:path) as CFURL,"public.png" as CFString,1,nil)!
CGImageDestinationAddImage(destination,image,nil)
precondition(CGImageDestinationFinalize(destination),"Icon export failed")
// Fail loudly if a future renderer regression exports an empty or single-color bitmap.
let pixels=context.data!.assumingMemoryBound(to:UInt8.self)
let background=Array(UnsafeBufferPointer(start:pixels,count:3))
let center=Array(UnsafeBufferPointer(start:pixels+(512*1024+512)*4,count:3))
precondition(background != center && background.contains(where:{$0 > 100}),"Icon is blank")
print("Rendered opaque 1024×1024 icon:",path)
