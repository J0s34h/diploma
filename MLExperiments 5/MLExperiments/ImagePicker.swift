//
//  ImagePicker.swift
//  MLExperiments
//
//  Created by Yusuf Fayzullin on 07.04.2023.
//

import CoreML
import Foundation
import SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode)
    var presentationMode

    @Binding var image: UIImage?
    @Binding var metaData: NSDictionary?

    var model: Model

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

        @Binding var presentationMode: PresentationMode
        @Binding var image: UIImage?
        @Binding var metaData: NSDictionary?

        var model: Model

        init(presentationMode: Binding<PresentationMode>, image: Binding<UIImage?>, metaData: Binding<NSDictionary?>, model: Model) {
            _presentationMode = presentationMode
            _image = image
            _metaData = metaData
            self.model = model

        }

        func imagePickerController(_: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any])
        {
            let uiImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage

            metaData = info[UIImagePickerController.InfoKey.mediaMetadata] as? NSDictionary

            withAnimation(.easeInOut(duration: 0.5)) {
                self.image = uiImage
            }

            presentationMode.dismiss()
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            presentationMode.dismiss()
        }

    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(presentationMode: presentationMode, image: $image, metaData: $metaData, model: model)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController,
                                context _: UIViewControllerRepresentableContext<ImagePicker>) {}

}
