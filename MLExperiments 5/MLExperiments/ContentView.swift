//
//  ContentView.swift
//  MLExperiments
//
//  Created by Yusuf Fayzullin on 07.04.2023.
//

import CoreHaptics
import CoreML
import SwiftUI
import UIKit

struct ContentView: View {
    @State var showImagePickerView = false
    @State var image: UIImage? = nil
    @State var metaData: NSDictionary? = nil
    @State var infoMessage = ""

    @State var pickerButtonIsOn = true

    let imageProcessor = ImageProcessor.shared

    @State var spinnerOn = false
    @State var infoOn = true

    @State private var engine: CHHapticEngine?

    @State var model: Model = .defocused

    var body: some View {
        //  GeometryReader { geometry in

        ZStack(alignment: .center) {
            Image("background")
                .resizable()
                .ignoresSafeArea()

            if spinnerOn {
                SpinnerView()
                    .frame(width: 80, height: 80, alignment: .center)
                    .transition(.asymmetric(insertion: .scale, removal: .opacity))
                    .zIndex(1)
            }

            VStack(spacing: 10) {
                Spacer()

                if image != nil {
                    ImageInfoView(image: $image, metaData: $metaData)
//                    ZoomableView(size: CGSize(width: 300, height: 300), min: 1.0, max: 6.0, showsIndicators: false) {
//                        Image(uiImage: image!)
//                            .resizable()
//                            .scaledToFit()
//                            .background(Color.black)
//                            //.clipped()
//                            .onTapGesture(count: 2) {
//                                complexSuccess()
//                                loadAi(model: self.model)
//                            }
//                    }

                    ZoomableScrollView {
                        Image(uiImage: image!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .onTapGesture(count: 2) {
                                complexSuccess()
                                loadAi(model: self.model)

                            }
                    }
                }

                if infoOn && !infoMessage.isEmpty {
                    RoundedView(label: $infoMessage)
                }

                if pickerButtonIsOn {
                    HStack {
                        Button(action: {
                            self.showImagePickerView = true
                        }) {
                            buttonView(label: "Gallery", image: "photo.stack", isSystem: true)
                        }
                        .sheet(isPresented: self.$showImagePickerView) {
                            ImagePicker(image: self.$image, metaData: self.$metaData, model: self.model)
                        }

                        if image != nil {
//                            Button(action: {
//                                loadAi(model: .motion2)
//                            }) {
//                                buttonView(label: "Motion 2", image: "button_blur")
//                            }

                            Button(action: {
                                loadAi(model: .defocused)
                            }) {
                                buttonView(label: "Defocused", image: "button_blur")
                            }

                            Button(action: {
                                loadAi(model: .motion)
                            }) {
                                buttonView(label: "Motion", image: "button_motion")
                            }

                            Button(action: {
                                loadAi(model: .superResolution)
                            }) {
                                buttonView(label: "SR", image: "a.magnify", isSystem: true)
                            }

//                            Button(action: {
//                                loadAi(model: .superResolution2)
//                            }) {
//                                buttonView(label: "SR2", image: "a.magnify", isSystem: true)
//                            }

                            ShareLink(
                                item: Image(uiImage: image!),
                                preview: SharePreview("Restorated image", image: Image(uiImage: image!))

                            ) {
                                buttonView(label: "Share", image: "square.and.arrow.up.circle.fill", isSystem: true)
                            }
                        }
                    }.padding(5)
                        .background(.black.opacity(0.3))
                        .cornerRadius(15)
                }

                Spacer()
            }.onAppear {
                prepareHaptics()
            }
        }
    }

    func runAi() {
        if model == .unknown {
            return
        }

        infoOn = true
        pickerButtonIsOn = false

//        imageProcessor.prediction(image: self.image!, model: self.model, completion: { img in
//            withAnimation(.easeInOut(duration: 2)) {
//                self.image = img
//                infoOn = false
//                spinnerOn = false
//                pickerButtonIsOn = true
//            }
//        })

        imageProcessor.predictionBySegments(image: image!, model: model, progress: { percent in
            infoMessage = "Proccesing... \(percent)%"
        }, completion: { img in
            withAnimation(.easeInOut(duration: 2)) {
                self.image = img
                infoOn = false
                spinnerOn = false
                pickerButtonIsOn = true
            }
        })
    }

    func loadAi(model: Model) {
        infoOn = true
        pickerButtonIsOn = false
        infoMessage = "Preparing AI. Pleas wait..."

        withAnimation(.easeInOut(duration: 2)) {
            spinnerOn = true
        }
        self.model = model

        runAi()
    }

    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }
    }

    func complexSuccess() {
        // make sure that the device supports haptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        var events = [CHHapticEvent]()

        // create one intense, sharp tap
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(event)

        // convert those events into a pattern and play it immediately
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play pattern: \(error.localizedDescription).")
        }
    }
}

struct RoundedView: View {
    @Binding var label: String

    let size = CGFloat(20)

    var body: some View {
        // AvenirNext-Bold
        Text(label)
            .foregroundStyle(.white)
            .font(.custom(
                "AvenirNext-Bold",
                fixedSize: size
            ))
            .padding(20)
            .background(.black.opacity(0.3))
            .cornerRadius(15)
    }
}

struct ImageInfoView: View {
    @Binding var image: UIImage?
    @Binding var metaData: NSDictionary?

    let size = CGFloat(10)
//    ColorModel = RGB;
//            DPIHeight = 72;
//            DPIWidth = 72;
//            Depth = 8;
//            Orientation = 6;
//            PixelHeight = 2448;
//            PixelWidth = 3264;
    var body: some View {
        // AvenirNext-Bold
        VStack(alignment: .leading) {
            Text("Color: \(getColorInfo())")
                .foregroundStyle(.white)
                .font(.custom(
                    "AvenirNext-Bold",
                    fixedSize: size
                ))
            Text("Size: \(getSizeInfo())")
                .foregroundStyle(.white)
                .font(.custom(
                    "AvenirNext-Bold",
                    fixedSize: size
                ))
        }
        .padding(10)
        .background(.black.opacity(0.3))
        .cornerRadius(15)
    }

    func getSizeInfo() -> String {
        if image == nil {
            return "-"
        }

        let w = Int(image!.size.width)
        let h = Int(image!.size.height)

        return "\(w) x \(h)"
    }

    func getColorInfo() -> String {
        guard let colorInfo = metaData?.value(forKey: "ColorModel") as? String else {
            if let colorInfo = image?.cgImage?.bitmapInfo.pixelFormat.rawValue {
                return colorInfo
            } else {
                return "-"
            }
        }
        return colorInfo
    }
}

struct buttonView: View {
    @State var label: String
    @State var image: String
    @State var isSystem = false

    let buttonSizeMax = CGFloat(30)
    let buttonSizeMin = CGFloat(30)
    let fontSize = CGFloat(10)

    let size = CGFloat(20)

    var body: some View {
        VStack {
            if !isSystem {
                Image(image)
                    .resizable()
                    .frame(minWidth: buttonSizeMin, maxWidth: buttonSizeMax, minHeight: buttonSizeMin, maxHeight: buttonSizeMax)
                    .foregroundColor(.white)
            } else {
                Image(systemName: image)
                    .resizable()
                    .frame(minWidth: buttonSizeMin, maxWidth: buttonSizeMax, minHeight: buttonSizeMin, maxHeight: buttonSizeMax)
                    .foregroundColor(.white)
            }
            Text(label).foregroundStyle(.white)
                .font(.custom(
                    "AvenirNext-Bold",
                    fixedSize: fontSize
                ))
        }
    }
}

struct SpinnerView: View {
    @State var isRotating = false

    var body: some View {
        ZStack {
            ZStack {
                Image("shadow")
                // Image("icon-bg")
                Image("pink-top")
                    .resizable()
                    .rotationEffect(.degrees(isRotating ? 320 : -360))
                    .hueRotation(.degrees(isRotating ? -270 : 60))

                Image("pink-left")
                    .resizable()
                    .rotationEffect(.degrees(isRotating ? -360 : 180))
                    .hueRotation(.degrees(isRotating ? -220 : 300))

                Image("blue-middle")
                    .resizable()
                    .rotationEffect(.degrees(isRotating ? -360 : 420))
                    .hueRotation(.degrees(isRotating ? -150 : 0))
                    .rotation3DEffect(.degrees(75), axis: (x: isRotating ? 1 : 5, y: 0, z: 0))

                Image("blue-right")
                    .resizable()
                    .rotationEffect(.degrees(isRotating ? -360 : 420))
                    .hueRotation(.degrees(isRotating ? 720 : -50))
                    .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: isRotating ? -5 : 15))

                Image("intersect")
                    .resizable()
                    .rotationEffect(.degrees(isRotating ? 30 : -420))
                    .hueRotation(.degrees(isRotating ? 0 : 720))
                    .rotation3DEffect(.degrees(15), axis: (x: 1, y: 1, z: 1), perspective: isRotating ? 5 : -5)

                Image("green-right")
                    .resizable()
                    .rotationEffect(.degrees(isRotating ? -300 : 360))
                    .hueRotation(.degrees(isRotating ? 300 : -15))
                    .rotation3DEffect(.degrees(15), axis: (x: 1, y: isRotating ? -1 : 1, z: 0), perspective: isRotating ? -1 : 1)

                Image("green-left")
                    .resizable()
                    .rotationEffect(.degrees(isRotating ? 360 : -360))
                    .hueRotation(.degrees(isRotating ? 180 : 50))
                    .rotation3DEffect(.degrees(75), axis: (x: 1, y: isRotating ? -5 : 15, z: 0))

                Image("bottom-pink")
                    .resizable()
                    .rotationEffect(.degrees(isRotating ? 400 : -360))
                    .hueRotation(.degrees(isRotating ? 0 : 230))
                    .opacity(0.25)
                    .blendMode(.multiply)
                    .rotation3DEffect(.degrees(75), axis: (x: 5, y: isRotating ? 1 : -45, z: 0))
            }
            .blendMode(isRotating ? .hardLight : .difference)

            Image("highlight")
                .resizable()
                .rotationEffect(.degrees(isRotating ? 360 : 250))
                .hueRotation(.degrees(isRotating ? 0 : 230))
                .padding()
                .onAppear {
                    withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                        isRotating.toggle()
                    }
                }
        }.scaleEffect(0.3)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
