//
//  ImageProcessorExt.swift
//  MLExperiments
//
//  Created by Yusuf Faizullin on 09.04.2023.
//

import CoreImage
import Foundation

#if canImport(UIKit)
    // iOS, tvOS, and watchOS â use UIColor
    import UIKit
#elseif canImport(AppKit)
// macOS â use NSColor
#else
    // all other platforms â use a custom color object
#endif

import CoreML

extension CIImage {

    var buffer: CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let width = Int(extent.width)
        let height = Int(extent.height)

//        CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, kCVPixelFormatType_OneComponent16Half, attrs, &pixelBuffer)

        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_OneComponent16Half,
                                         attrs,
                                         &pixelBuffer)

        guard status == kCVReturnSuccess,
              let buffer = pixelBuffer else { return nil }

        let context = CIContext()
        context.render(self, to: buffer)
        return buffer
    }
}

func buffer(from image: UIImage) -> CVPixelBuffer? {
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard status == kCVReturnSuccess else {
        return nil
    }

    CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

    context?.translateBy(x: 0, y: image.size.height)
    context?.scaleBy(x: 1.0, y: -1.0)

    UIGraphicsPushContext(context!)
    image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

    return pixelBuffer
}

func cropImageToSquare(image: UIImage) -> UIImage? {
    var imageHeight = image.size.height
    var imageWidth = image.size.width

    if imageHeight > imageWidth {
        imageHeight = imageWidth
    } else {
        imageWidth = imageHeight
    }

    let size = CGSize(width: imageWidth, height: imageHeight)

    let refWidth = CGFloat(image.cgImage!.width)
    let refHeight = CGFloat(image.cgImage!.height)

    let x = (refWidth - size.width) / 2
    let y = (refHeight - size.height) / 2

    let cropRect = CGRect(x: x, y: y, width: size.height, height: size.width)
    if let imageRef = image.cgImage!.cropping(to: cropRect) {
        return UIImage(cgImage: imageRef, scale: 0, orientation: image.imageOrientation)
    }

    return nil
}

// Usage:
//     let mlMultiArray:MLMultiArray = uiImage.mlMultiArray()
//
// or if you need preprocess ...
//     let preProcessedMlMultiArray:MLMultiArray = uiImage.mlMultiArray(scale: 127.5, rBias: -1, gBias: -1, bBias: -1)
//
// or if you have gray scale image ...
//     let grayScaleMlMultiArray:MLMultiArray = uiImage.mlMultiArrayGrayScale()
extension UIImage {

    func mlMultiArray(scale preprocessScale: Double = 255, rBias preprocessRBias: Double = 0, gBias preprocessGBias: Double = 0, bBias preprocessBBias: Double = 0) -> MLMultiArray {
        let imagePixel = getPixelRgb(scale: preprocessScale, rBias: preprocessRBias, gBias: preprocessGBias, bBias: preprocessBBias)
        let size = self.size
        let imagePointer: UnsafePointer<Double> = UnsafePointer(imagePixel)
        let mlArray = try! MLMultiArray(shape: [1, 3,  NSNumber(value: Float(size.width)), NSNumber(value: Float(size.height))], dataType: MLMultiArrayDataType.double)
        mlArray.dataPointer.initializeMemory(as: Double.self, from: imagePointer, count: imagePixel.count)
        return mlArray
    }

    func mlMultiArrayGrayScale(scale preprocessScale: Double = 255, bias preprocessBias: Double = 0) -> MLMultiArray {
        let imagePixel = getPixelGrayScale(scale: preprocessScale, bias: preprocessBias)
        let size = self.size
        let imagePointer: UnsafePointer<Double> = UnsafePointer(imagePixel)
        let mlArray = try! MLMultiArray(shape: [1,  NSNumber(value: Float(size.width)), NSNumber(value: Float(size.height))], dataType: MLMultiArrayDataType.double)
        mlArray.dataPointer.initializeMemory(as: Double.self, from: imagePointer, count: imagePixel.count)
        return mlArray
    }

    func mlMultiArrayYcbCr(scale preprocessScale: Double = 255, rBias preprocessRBias: Double = 0, gBias preprocessGBias: Double = 0, bBias preprocessBBias: Double = 0) -> MLMultiArray {
        let imagePixel = getPixelYcbCr(scale: preprocessScale, rBias: preprocessRBias, gBias: preprocessGBias, bBias: preprocessBBias)
        let size = self.size
        let imagePointer: UnsafePointer<Double> = UnsafePointer(imagePixel)
        let mlArray = try! MLMultiArray(shape: [1, 3,  NSNumber(value: Float(size.width)), NSNumber(value: Float(size.height))], dataType: MLMultiArrayDataType.double)
        mlArray.dataPointer.initializeMemory(as: Double.self, from: imagePointer, count: imagePixel.count)
        return mlArray
    }

    func getPixelYcbCr(scale preprocessScale: Double = 255, rBias preprocessRBias: Double = 0, gBias preprocessGBias: Double = 0, bBias preprocessBBias: Double = 0) -> [Double]
    {
        guard let cgImage = cgImage else {
            return []
        }
        let bytesPerRow = cgImage.bytesPerRow

        let width = cgImage.width
        let height = cgImage.height
        var bytesPerPixel = 4
        var pixOffset = 0
        if cgImage.alphaInfo == .none {
            bytesPerPixel = 3
        }

        let pixelFormat = cgImage.bitmapInfo.pixelFormat

        let pixelData = cgImage.dataProvider!.data! as Data

        var r_buf: [Double] = []
        var g_buf: [Double] = []
        var b_buf: [Double] = []

        var r: Double = 0
        var g: Double = 0
        var b: Double = 0

        for j in 0 ..< height {
            for i in 0 ..< width {
                let pixelInfo = bytesPerRow * j + i * bytesPerPixel

                if pixelFormat == .bgra {

                    r = Double(pixelData[pixelInfo + 2])
                    g = Double(pixelData[pixelInfo + 1])
                    b = Double(pixelData[pixelInfo])
                } else {

                    r = Double(pixelData[pixelInfo])
                    g = Double(pixelData[pixelInfo + 1])
                    b = Double(pixelData[pixelInfo + 2])
                }

//                    out.Y <= 16+(((r<<6)+(r<<1)+(g<<7)+g+(b<<4)+(b<<3)+b)>>8);
//                    out.Cb <= 128 + ((-((r<<5)+(r<<2)+(r<<1))-((g<<6)+(g<<3)+(g<<1))+(b<<7)-(b<<4))>>8);
//                    out.Cr <= 128 + (((r<<7)-(r<<4)-((g<<6)+(g<<5)-(g<<1))-((b<<4)+(b<<1)))>>8);
//
                let y = 0.299 * r + 0.587 * g + 0.114 * b
                let cb = 128 - 0.168736 * r - 0.331364 * g + 0.5 * b
                let cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b

                r_buf.append(Double(Double(y) / preprocessScale) + preprocessRBias)
                g_buf.append(Double(Double(cb) / preprocessScale) + preprocessGBias)
                b_buf.append(Double(Double(cr) / preprocessScale) + preprocessBBias)

            }
        }
        return ((b_buf + g_buf) + r_buf)
        // return ((r_buf + g_buf) + b_buf)
    }

    func getPixelRgb(scale preprocessScale: Double = 255, rBias preprocessRBias: Double = 0, gBias preprocessGBias: Double = 0, bBias preprocessBBias: Double = 0) -> [Double]
    {
        guard let cgImage = cgImage else {
            return []
        }
        let bytesPerRow = cgImage.bytesPerRow

        // print("alphaInfo = \(cgImage.alphaInfo)")
//    case none = 0 /* For example, RGB. */
//    case premultipliedLast = 1 /* For example, premultiplied RGBA */
//    case premultipliedFirst = 2 /* For example, premultiplied ARGB */
//    case last = 3 /* For example, non-premultiplied RGBA */
//    case first = 4 /* For example, non-premultiplied ARGB */
//    case noneSkipLast = 5 /* For example, RGBX. */
        //   print("pixelFormat = \(cgImage.bitmapInfo.pixelFormat)")

        let width = cgImage.width
        let height = cgImage.height
        var bytesPerPixel = 4
        var pixOffset = 0
        if cgImage.alphaInfo == .none {
            bytesPerPixel = 3
        }

        let pixelFormat = cgImage.bitmapInfo.pixelFormat

        let pixelData = cgImage.dataProvider!.data! as Data

        var r_buf: [Double] = []
        var g_buf: [Double] = []
        var b_buf: [Double] = []

        for j in 0 ..< height {
            for i in 0 ..< width {
                let pixelInfo = bytesPerRow * j + i * bytesPerPixel

                if pixelFormat == .bgra {

                    let r = Double(pixelData[pixelInfo + 2])
                    let g = Double(pixelData[pixelInfo + 1])
                    let b = Double(pixelData[pixelInfo])
                    r_buf.append(Double(r / preprocessScale) + preprocessRBias)
                    g_buf.append(Double(g / preprocessScale) + preprocessGBias)
                    b_buf.append(Double(b / preprocessScale) + preprocessBBias)

                } else {

                    let r = Double(pixelData[pixelInfo])
                    let g = Double(pixelData[pixelInfo + 1])
                    let b = Double(pixelData[pixelInfo + 2])
                    r_buf.append(Double(r / preprocessScale) + preprocessRBias)
                    g_buf.append(Double(g / preprocessScale) + preprocessGBias)
                    b_buf.append(Double(b / preprocessScale) + preprocessBBias)

                }

            }
        }
        return ((b_buf + g_buf) + r_buf)
        // return ((r_buf + g_buf) + b_buf)
    }

    func getPixelGrayScale(scale preprocessScale: Double = 255, bias preprocessBias: Double = 0) -> [Double]
    {
        guard let cgImage = cgImage else {
            return []
        }
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 2
        let pixelData = cgImage.dataProvider!.data! as Data

        var buf: [Double] = []

        for j in 0 ..< height {
            for i in 0 ..< width {
                let pixelInfo = bytesPerRow * j + i * bytesPerPixel
                let v = Double(pixelData[pixelInfo])
                buf.append(Double(v / preprocessScale) + preprocessBias)
            }
        }
        return buf
    }

}

extension MLMultiArray {

    func findNearNonNan(mlArray: UnsafeMutablePointer<Float32>, index: Int, max: Int) -> Float32 {

        var idx = index
        var b = mlArray[idx]
        while b.isNaN, idx < max - 1 {
            idx = idx + 1
            b = mlArray[idx]
        }
        if b.isNaN {
            print("ALL pixels NAN")
            return 0

        }

        return b
    }

    func postProcessImage(size: Int = 128) -> UIImage? {

        let capacity = size * size * 3
        let rawPointer = malloc(capacity)!
        let bytes = rawPointer.bindMemory(to: UInt8.self, capacity: capacity)

        let mlArray = dataPointer.bindMemory(to: Float32.self, capacity: capacity)
        for index in 0 ..< count / 3 {
            // BGR
            var b0 = mlArray[index]
            if b0.isNaN { b0 = findNearNonNan(mlArray: mlArray, index: index, max: capacity) }
            var b1 = mlArray[index + size * size]
            if b1.isNaN { b1 = findNearNonNan(mlArray: mlArray, index: index + size * size, max: capacity) }
            var b2 = mlArray[index + size * size * 2]
            if b2.isNaN { b2 = findNearNonNan(mlArray: mlArray, index: index + size * size * 2, max: capacity) }

            bytes[index * 3 + 2] = UInt8(max(min(b0 * 255, 255), 0))
            bytes[index * 3 + 1] = UInt8(max(min(b1 * 255, 255), 0))
            bytes[index * 3 + 0] = UInt8(max(min(b2 * 255, 255), 0))
        }

        let selftureSize = size * size * 3

        let provider = CGDataProvider(dataInfo: nil, data: rawPointer, size: selftureSize, releaseData: { _, data, _ in
            data.deallocate()
        })!

        let rawBitmapInfo = CGImageAlphaInfo.none.rawValue
        let bitmapInfo = CGBitmapInfo(rawValue: rawBitmapInfo)

        let pColorSpace = CGColorSpaceCreateDeviceRGB()

        let rowBytesCount = size * 3
        let cgImage = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: rowBytesCount, space: pColorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: CGColorRenderingIntent.defaultIntent)!
        let uiImage = UIImage(cgImage: cgImage)

        return uiImage
    }

}

public enum PixelFormat: String {
    case abgr = "ABGR"
    case argb = "ARGB"
    case bgra = "BGRA"
    case rgba = "RGBA"
    case unknown = "UNKNOWN"
}

public extension CGBitmapInfo {
    static var byteOrder16Host: CGBitmapInfo {
        return CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) ? .byteOrder16Little : .byteOrder16Big
    }

    static var byteOrder32Host: CGBitmapInfo {
        return CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) ? .byteOrder32Little : .byteOrder32Big
    }
}

public extension CGBitmapInfo {
    var pixelFormat: PixelFormat {

        // AlphaFirst â the alpha channel is next to the red channel, argb and bgra are both alpha first formats.
        // AlphaLast â the alpha channel is next to the blue channel, rgba and abgr are both alpha last formats.
        // LittleEndian â blue comes before red, bgra and abgr are little endian formats.
        // Little endian ordered pixels are BGR (BGRX, XBGR, BGRA, ABGR, BGR).
        // BigEndian â red comes before blue, argb and rgba are big endian formats.
        // Big endian ordered pixels are RGB (XRGB, RGBX, ARGB, RGBA, RGB).

        let alphaInfo: CGImageAlphaInfo? = CGImageAlphaInfo(rawValue: rawValue & type(of: self).alphaInfoMask.rawValue)
        let alphaFirst: Bool = alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst
        let alphaLast: Bool = alphaInfo == .premultipliedLast || alphaInfo == .last || alphaInfo == .noneSkipLast
        let endianLittle: Bool = contains(.byteOrder32Little)

        // This is slipperyâ¦ while byte order host returns little endian, default bytes are stored in big endian
        // format. Here we just assume if no byte order is given, then simple RGB is used, aka big endian, thoughâ¦

        if alphaFirst, endianLittle {
            // print("BGRA")
            return .bgra
        } else if alphaFirst {
            // print("ARGB")
            return .argb
        } else if alphaLast, endianLittle {
            // print("ABGR")
            return .abgr
        } else if alphaLast {
            // print("RGBA")
            return .rgba
        }
        return .unknown
    }
}
