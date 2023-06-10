//
//  ImageProcessor.swift
//  MLExperiments
//
//  Created by Yusuf Faizullin on 09.04.2023.
//

import CoreML
import Foundation
import Vision
#if canImport(UIKit)
    // iOS, tvOS, and watchOS – use UIColor
    import UIKit
#elseif canImport(AppKit)
// macOS – use NSColor
#else
    // all other platforms – use a custom color object
#endif

enum Model: String {
    // case grl = "GRL_128"
    case motion = "Uformer_256"
//    case motion2 = "MPRNetDebluring"
    // case tlc = "TLC_128"
    case defocused = "Restormer_128"
    case superResolution = "realesrgan512"
//    case superResolution2 = "SR_64"
    case unknown = "-"
}

class ImageProcessor {
    public var modelMotion: Uformer_256?

//    public var tlcModel: TLC_128?
    public var modelDefocus: Restormer_128?
    public var modelSR2: SR_64?
    public var modelSR: VNCoreMLModel?

    public var modelMotion2: VNCoreMLModel?

    var modelSize = 128

    static var shared = ImageProcessor()

    var currentModelType: Model = .unknown
//
//    func loadPretrained(model: Model, modelClass: (MLModel), completion: @escaping (Bool) -> ()){
//        MLModel.load(contentsOf: Bundle.main.url(forResource: model.rawValue, withExtension: "mlmodelc")!){[weak self] result in
//            switch result {
//            case .success(let m):
//                print("Model loaded and ready.")
//                self!.currentModel = modelClass(m)
//            case .failure(let error):
//                print("Error loading model: \(error)")
//            }
//        }
//    }

    func cleanMem(model: Model) {

        DataCache.instance.cleanAll()
        switch model {

        case .motion:
            modelDefocus = nil
            modelSR = nil
            modelSR2 = nil
            modelMotion2 = nil

//        case .motion2:
//            modelDefocus = nil
//            modelSR = nil
//            modelSR2 = nil
//            modelMotion = nil

        case .defocused:
            modelSR = nil
            modelSR2 = nil
            modelMotion = nil
            modelMotion2 = nil

        case .superResolution:
            modelDefocus = nil
            modelSR2 = nil
            modelMotion = nil
            modelMotion2 = nil

//        case .superResolution2:
//            modelDefocus = nil
//            modelSR = nil
//            modelMotion = nil
//            modelMotion2 = nil

        case .unknown:
            modelDefocus = nil
            modelSR = nil
            modelSR2 = nil
            modelMotion = nil
            modelMotion2 = nil
        }
    }

    func loadModel(model: Model, completion: @escaping (Bool) -> Void) {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        cleanMem(model: model)

        switch model {
        case .motion:

            modelSize = 256
            if modelMotion == nil {

                MLModel.load(
                    contentsOf:
                    Bundle.main.url(
                        forResource: model.rawValue,
                        withExtension: "mlmodelc"
                    )!,
                    configuration: config
                ) { [weak self] result in
                    switch result {
                    case let .success(m):
                        print("Model loaded and ready.")
                        self?.modelMotion = Uformer_256(model: m)
                        completion(true)

                    case let .failure(error):
                        print("Error loading model: \(error)")
                        completion(false)

                    }
                }
            } else {
                completion(true)
            }

        case .defocused:
            modelSize = 128

            if modelDefocus == nil {

                MLModel.load(contentsOf: Bundle.main.url(forResource: model.rawValue, withExtension: "mlmodelc")!, configuration: config) { [weak self] result in
                    switch result {
                    case let .success(m):
                        print("Model loaded and ready.")
                        self!.modelDefocus = Restormer_128(model: m)
                        completion(true)
                        return
                    case let .failure(error):
                        print("Error loading model: \(error)")
                        completion(false)
                    }
                }
            } else {
                completion(true)
            }

//        case .superResolution2:
//            modelSize = 64
//
//            if modelSR2 == nil {
//
//                MLModel.load(contentsOf: Bundle.main.url(forResource: model.rawValue, withExtension: "mlmodelc")!, configuration: config) { [weak self] result in
//                    switch result {
//                    case .success(let m):
//                        print("Model loaded and ready.")
//                        self!.modelSR2 = SR_64(model: m)
//                        completion(true)
//                        return
//                    case .failure(let error):
//                        print("Error loading model: \(error)")
//                        completion(false)
//                    }
//                }
//            }else {
//                completion(true)
//            }
//
//        case .motion2:
//            if modelMotion2 == nil {
//
//                do {
//                    modelSize = 512
//                    modelMotion2 = try VNCoreMLModel(for: MPRNetDebluring(configuration: config).model)
//                    completion(true)
//
//
//                } catch {
//                    print(error.localizedDescription)
//                    completion(false)
//
//                }
//            }else {
//                completion(true)
//            }
//
        case .superResolution:
            if modelSR == nil {

                do {
                    modelSize = 512
                    config.computeUnits = .cpuAndNeuralEngine
                    modelSR = try VNCoreMLModel(for: realesrgan512(configuration: config).model)
                    completion(true)

                } catch {
                    print(error.localizedDescription)
                    completion(false)

                }
            } else {
                completion(true)
            }

        case .unknown:
            print("unknown model")
            completion(false)
            return
        }

    }

    public func prediction(image: UIImage, model: Model, completion: @escaping (UIImage?) -> Void) {
        loadModel(model: model) { modelLoaded in
            if modelLoaded {
                if [.superResolution].contains(model) {
                    self.predictImage(image: image, model: model) { img in
                        completion(img)
                    }
                } else {
                    self.predictMultiArray(image: image, model: model) { img in
                        completion(img)
                    }
                }
            } else {
                completion(nil)
            }
        }
    }

    func predictMultiArray(image: UIImage, model: Model, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global().async { [self] in

            var resizedImage = cropImageToSquare(image: image)!
            resizedImage = resizedImage.resized(to: CGSize(width: modelSize, height: modelSize))
            print("\(resizedImage.size.width)x\(resizedImage.size.height)")

            // Core ML
            if model == .motion {
                let multiArray = resizedImage.mlMultiArray()
                guard let out = try? modelMotion?.prediction(input: multiArray) else {
                    completion(nil)
                    return
                }
                guard let img = out.activation_out.postProcessImage(size: modelSize) else {
                    completion(nil)
                    return
                }
                completion(img)
            }

            if model == .defocused {
                let multiArray = resizedImage.mlMultiArray()
                guard let out = try? modelDefocus?.prediction(input: multiArray) else {
                    completion(nil)
                    return
                }
                guard let img = out.activation_out.postProcessImage(size: modelSize) else {
                    completion(nil)
                    return
                }
                completion(img)
            }

        }
    }

    func predictImage(image: UIImage, model: Model, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global().async { [self] in

            var vnModel: VNCoreMLModel?

            if model == .superResolution {
                vnModel = self.modelSR
            }

            let request = VNCoreMLRequest(model: vnModel!) { request, _ in
                if let bestResult = request.results?.first as? VNPixelBufferObservation {
                    let img = UIImage(pixelBuffer: bestResult.pixelBuffer)
                    completion(img)

                } else {
                    completion(nil)
                }
            }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)

            guard let ciImage = CIImage(image: image) else {
                completion(nil)
                return
            }

            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
                return
            }
        }
    }

    public func predictionBySegments(
        image: UIImage,
        model: Model,
        progress: @escaping (Int) -> Void,
        completion: @escaping (UIImage?) -> Void
    ) {

        loadModel(model: model) { [self] modelLoaded in

            if !modelLoaded {
                completion(nil)
                return
            }

            if Int(image.size.height) < modelSize || Int(image.size.width) < self.modelSize {
                prediction(image: image, model: model) { img in
                    completion(img)
                }
                return
            }

            let imageRects: [CGRect] = self.calcImageRects(image: image, size: self.modelSize)
            print("Image segments for AI: \(imageRects.count)")

            if  [.superResolution].contains(model) {
                self.predictionImageBySegments(
                    image: image, model: model,
                    imageRects: imageRects,
                    progress: progress,
                    completion: completion
                )
            } else {
                self.predictionMultiArrayBySegments(
                    image: image,
                    model: model,
                    imageRects: imageRects,
                    progress: progress,
                    completion: completion
                )
            }
        }
    }

    public func predictionImageBySegments(image: UIImage, model: Model, imageRects: [CGRect], progress: @escaping (Int) -> Void, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global().async { [self] in

            // var rImages: [UIImage] = []
            var imageKeys: [String] = []
            var segment = 1
            progress(0)

            var vnModel: VNCoreMLModel?

            if model == .superResolution {
                vnModel = self.modelSR
            }

//            if model == .motion2 {
//                vnModel = modelMotion2
//            }

            let request = VNCoreMLRequest(model: vnModel!) { request, _ in
                if let bestResult = request.results?.first as? VNPixelBufferObservation {
                    let img = UIImage(pixelBuffer: bestResult.pixelBuffer)

                    let key = UUID().uuidString
                    print("Write image to cache as \(key) image: \(image.size)")
                    DataCache.instance.write(image: img!, forKey: key)

                    // rImages.append(img!)
                    imageKeys.append(key)

                    print("Running segment \(segment) of \(imageRects.count)")

                    progress(segment * 100 / imageRects.count)
                    segment = segment + 1

                    // if rImages.count == imageRects.count {
                    if imageKeys.count == imageRects.count {
                        let size =  CGSize(width: image.size.width, height: image.size.height)
                        let scale: Int
                        if model == .superResolution {
                            scale = 4
                        } else {
                            scale = 1
                        }
                        // let resultImage = self.makeOneBigImage(size: size, images: rImages, rects: imageRects)
                        let resultImage = self.makeOneBigImageFromCache(size: size, imageKeys: imageKeys, rects: imageRects, scale: scale)
                        print("Running makeOneBigImage done")
                        DispatchQueue.main.async {
                            completion(resultImage)
                        }
                    }

                } else {
                    fatalError("Can't get best result")
                }
            }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)

            imageRects.forEach { rect in

                let img = self.cropImage(image, toRect: rect)
                guard let ciImage = CIImage(image: img!) else { return }

                let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)

                do {
                    try handler.perform([request])
                } catch {
                    completion(nil)
                    return
                }
            }
        }
    }

    public func predictionMultiArrayBySegments(image: UIImage, model: Model, imageRects: [CGRect], progress: @escaping (Int) -> Void, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global().async { [self] in

            // var rImages: [UIImage] = []
            var imageKeys: [String] = []
            var segment = 1
            progress(0)

            imageRects.forEach { rect in

                let img = self.cropImage(image, toRect: rect)

                print("Running MultiArray segment \(segment) of \(imageRects.count)")

                if model == .motion {
                    let multiArray = img!.mlMultiArray()
                    guard let out = try? modelMotion?.prediction(input: multiArray) else {
                        completion(nil)
                        return
                    }
                    guard let rImg = out.activation_out.postProcessImage(size: modelSize) else {
                        completion(nil)
                        return
                    }
                    let key = UUID().uuidString
                    print("Write image to cache as \(key)")
                    DataCache.instance.write(image: rImg, forKey: key)
                    imageKeys.append(key)
                    // rImages.append(rImg)
                }

                if model == .defocused {
                    let multiArray = img!.mlMultiArray()
                    guard let out = try? modelDefocus?.prediction(input: multiArray) else {
                        completion(nil)
                        return
                    }
                    guard let rImg = out.activation_out.postProcessImage(size: modelSize) else {
                        completion(nil)
                        return
                    }
                    let key = UUID().uuidString
                    print("Write image to cache as \(key)")
                    DataCache.instance.write(image: rImg, forKey: key)

                    imageKeys.append(key)
                    // rImages.append(rImg)
                }

//                if model == .superResolution2 {
//                    let multiArray = img!.mlMultiArray()
//                    guard let out = try? modelSR2?.prediction(input: multiArray) else {
//                        completion(nil)
//                        return
//                    }
//                    guard let rImg = out.output.postProcessImage(size: modelSize*4) else {
//                        completion(nil)
//                        return
//                    }
//                    //rImages.append(rImg)
//                    let key = UUID().uuidString
//                    print("Write image to cache as \(key)")
//                    DataCache.instance.write(image: rImg, forKey: key)
//                    imageKeys.append(key)
//
//                }

                progress(segment * 100 / imageRects.count)
                segment = segment + 1
            }

            let size = CGSize(width: image.size.width, height: image.size.height)
            // let resultImage = self.makeOneBigImage(size: size, images: rImages, rects: imageRects)
            let resultImage = self.makeOneBigImageFromCache(size: size, imageKeys: imageKeys, rects: imageRects, scale: 1)
            print("Running makeOneBigImage done")
            DispatchQueue.main.async {
                completion(resultImage)
            }
        }
    }

    func makeOneBigImage(size: CGSize, images: [UIImage], rects: [CGRect]) -> UIImage {
        UIGraphicsBeginImageContext(size)

        for (index, img) in images.enumerated() {
            _ = CGRect(x: rects[index].minX, y: rects[index].minY, width: img.size.width, height: img.size.height)
            img.draw(in: rects[index])
        }

        let resultImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return resultImage
    }

    func makeOneBigImageFromCache(size: CGSize, imageKeys: [String], rects: [CGRect], scale: Int) -> UIImage {

        let newSize = CGSize(width: size.width * CGFloat(scale), height: size.height * CGFloat(scale))

        UIGraphicsBeginImageContext(newSize)

        for index in 0 ..< imageKeys.count {
            if let img = DataCache.instance.readImage(forKey: imageKeys[index]) {
                print("Read image from cache as \(imageKeys[index]) size: \(img.size)")
                let newRect = CGRect(x: rects[index].minX * CGFloat(scale), y: rects[index].minY * CGFloat(scale), width: img.size.width, height: img.size.height)
                img.draw(in: newRect)
            }
        }

        let resultImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return resultImage
    }

    func calcImageRects(image: UIImage, size: Int) -> [CGRect] {
        var imageRects: [CGRect] = []

        let hSegments = Int(image.size.width) / size

        let vSegments = Int(image.size.height) / size

        print("Image size: \(Int(image.size.width))x\(Int(image.size.height))")
        /// Prepaire  segments
        ///
        for vs in 0 ... vSegments {
            for hs in 0 ... hSegments {
                var x = hs * size
                var y = vs * size

                if x + size > Int(image.size.width) {
                    x = Int(image.size.width) - size
                }

                if y + size > Int(image.size.height) {
                    y = Int(image.size.height) - size
                }

                imageRects.append(CGRect(x: x, y: y, width: size, height: size))
            }
        }
        return imageRects
    }

    func cropImage(_ inputImage: UIImage, toRect cropRect: CGRect) -> UIImage? {
        // Perform cropping in Core Graphics
        guard let cutImageRef: CGImage = inputImage.cgImage?.cropping(to: cropRect)
        else {
            return nil
        }

        // Return image to UIImage
        let croppedImage = UIImage(cgImage: cutImageRef)
        return croppedImage
    }
}
