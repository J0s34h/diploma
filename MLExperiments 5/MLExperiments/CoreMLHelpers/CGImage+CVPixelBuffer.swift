import CoreGraphics
import CoreImage
import VideoToolbox

public extension CGImage {
    /**
       Converts the image to an ARGB `CVPixelBuffer`.
     */
    func pixelBuffer() -> CVPixelBuffer? {
        return pixelBuffer(width: width, height: height, orientation: .up)
    }

    /**
       Resizes the image to `width` x `height` and converts it to an ARGB
       `CVPixelBuffer`.
     */
    func pixelBuffer(width: Int, height: Int,
                     orientation: CGImagePropertyOrientation) -> CVPixelBuffer?
    {
        return pixelBuffer(width: width, height: height,
                           pixelFormatType: kCVPixelFormatType_32ARGB,
                           colorSpace: CGColorSpaceCreateDeviceRGB(),
                           alphaInfo: .noneSkipFirst,
                           orientation: orientation)
    }

    /**
       Converts the image to a grayscale `CVPixelBuffer`.
     */
    func pixelBufferGray() -> CVPixelBuffer? {
        return pixelBufferGray(width: width, height: height, orientation: .up)
    }

    /**
       Resizes the image to `width` x `height` and converts it to a grayscale
       `CVPixelBuffer`.
     */
    func pixelBufferGray(width: Int, height: Int,
                         orientation: CGImagePropertyOrientation) -> CVPixelBuffer?
    {
        return pixelBuffer(width: width, height: height,
                           pixelFormatType: kCVPixelFormatType_OneComponent8,
                           colorSpace: CGColorSpaceCreateDeviceGray(),
                           alphaInfo: .none,
                           orientation: orientation)
    }

    /**
       Resizes the image to `width` x `height` and converts it to a `CVPixelBuffer`
       with the specified pixel format, color space, and alpha channel.
     */
    func pixelBuffer(width: Int, height: Int,
                     pixelFormatType: OSType,
                     colorSpace: CGColorSpace,
                     alphaInfo: CGImageAlphaInfo,
                     orientation: CGImagePropertyOrientation) -> CVPixelBuffer?
    {

        // TODO: If the orientation is not .up, then rotate the CGImage.
        // See also: https://stackoverflow.com/a/40438893/
        assert(orientation == .up)

        var maybePixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         pixelFormatType,
                                         attrs as CFDictionary,
                                         &maybePixelBuffer)

        guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
            return nil
        }

        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, flags) else {
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, flags) }

        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: colorSpace,
                                      bitmapInfo: alphaInfo.rawValue)
        else {
            return nil
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }
}

public extension CGImage {
    /**
       Creates a new CGImage from a CVPixelBuffer.

       - Note: Not all CVPixelBuffer pixel formats support conversion into a
               CGImage-compatible pixel format.
     */
    static func create(pixelBuffer: CVPixelBuffer) -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        return cgImage
    }

    // Alternative implementation:
    static func create2(pixelBuffer: CVPixelBuffer) -> CGImage? {
        // This method creates a bitmap CGContext using the pixel buffer's memory.
        // It currently only handles kCVPixelFormatType_32ARGB images. To support
        // other pixel formats too, you'll have to change the bitmapInfo and maybe
        // the color space for the CGContext.

        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) else {
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        if let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                   width: CVPixelBufferGetWidth(pixelBuffer),
                                   height: CVPixelBufferGetHeight(pixelBuffer),
                                   bitsPerComponent: 8,
                                   bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue),
            let cgImage = context.makeImage()
        {
            return cgImage
        } else {
            return nil
        }
    }

    /**
      Creates a new CGImage from a CVPixelBuffer, using Core Image.
     */
    static func create(pixelBuffer: CVPixelBuffer, context: CIContext) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        return context.createCGImage(ciImage, from: rect)
    }
}
