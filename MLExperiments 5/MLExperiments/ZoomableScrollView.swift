//
//  ZoomableScrollView.swift
//  MLExperiments
//
//  Created by Yusuf Faizullin on 13.04.2023.
//
import Combine
import SwiftUI

public func mutate<T>(_ arg: inout T, _ body: (inout T) -> Void) {
    body(&arg)
}

class CenteringScrollView: UIScrollView {
    func centerContent() {
        assert(subviews.count == 1)
        mutate(&subviews[0].frame) {
            // not clear why view.center.{x,y} = bounds.mid{X,Y} doesn't work -- maybe transform?
            $0.origin.x = max(0, bounds.width - $0.width) / 2
            $0.origin.y = max(0, bounds.height - $0.height) / 2
            //  print($0.origin.y)
        }
    }

    override func layoutSubviews() {

        super.layoutSubviews()
        centerContent()
    }

}

struct ZoomableScrollView<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()

    }

    @State var doubleTap = PassthroughSubject<Void, Never>()

    var body: some View {
        ZoomableScrollViewImpl(content: content, doubleTap: doubleTap.eraseToAnyPublisher())
            .contentShape(Rectangle())
            // .background(.black.opacity(0.01))
            .cornerRadius(6)

            /// The double tap gesture is a modifier on a SwiftUI wrapper view, rather than just putting a UIGestureRecognizer on the wrapped view,
            /// because SwiftUI and UIKit gesture recognizers don't work together correctly correctly for failure and other interactions.
            .onTapGesture(count: 3) {
                doubleTap.send()
            }
    }
}

private struct ZoomableScrollViewImpl<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let doubleTap: AnyPublisher<Void, Never>

    func makeUIViewController(context: Context) -> ViewController {
        return ViewController(coordinator: context.coordinator, doubleTap: doubleTap)
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: content))
    }

    func updateUIViewController(_ viewController: ViewController, context _: Context) {
        viewController.update(content: content, doubleTap: doubleTap)
    }

    // MARK: - ViewController

    class ViewController: UIViewController, UIScrollViewDelegate {
        let coordinator: Coordinator
        let scrollView = CenteringScrollView()

        var doubleTapCancellable: Cancellable?
        var updateConstraintsCancellable: Cancellable?

        private var hostedView: UIView { coordinator.hostingController.view! }

        private var contentSizeConstraints: [NSLayoutConstraint] = [] {
            willSet { NSLayoutConstraint.deactivate(contentSizeConstraints) }
            didSet { NSLayoutConstraint.activate(contentSizeConstraints) }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { fatalError() }
        init(coordinator: Coordinator, doubleTap: AnyPublisher<Void, Never>) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
            view = scrollView

            scrollView.delegate = self  // for viewForZooming(in:)
            scrollView.maximumZoomScale = 5
            scrollView.minimumZoomScale = 1
            scrollView.zoomScale = 1
            scrollView.bouncesZoom = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.clipsToBounds = true

            let hostedView = coordinator.hostingController.view!
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
            ])

            updateConstraintsCancellable = scrollView.publisher(for: \.bounds).map(\.size).removeDuplicates()
                .sink { [unowned self] _ in
                    view.setNeedsUpdateConstraints()
                }
            doubleTapCancellable = doubleTap.sink { [unowned self] in handleDoubleTap() }

        }

        func update(content: Content, doubleTap: AnyPublisher<Void, Never>) {
            coordinator.hostingController.rootView = content
            scrollView.setNeedsUpdateConstraints()
            doubleTapCancellable = doubleTap.sink { [unowned self] in handleDoubleTap() }
        }

        func handleDoubleTap() {
            scrollView.setZoomScale(scrollView.zoomScale >= 1 ? scrollView.minimumZoomScale : 1, animated: true)
        }

        override func updateViewConstraints() {
            super.updateViewConstraints()
            let hostedContentSize = coordinator.hostingController.sizeThatFits(in: view.bounds.size)
            contentSizeConstraints = [
                hostedView.widthAnchor.constraint(equalToConstant: hostedContentSize.width),
                hostedView.heightAnchor.constraint(equalToConstant: hostedContentSize.height)
            ]

        }

        override func viewDidAppear(_: Bool) {
            // scrollView.zoom(to: hostedView.bounds, animated: false)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()

            let hostedContentSize = coordinator.hostingController.sizeThatFits(in: view.bounds.size)
            scrollView.minimumZoomScale = min(
                scrollView.bounds.width / hostedContentSize.width,
                scrollView.bounds.height / hostedContentSize.height
            )

        }

        func scrollViewDidZoom(_: UIScrollView) {
            // For some reason this is needed in both didZoom and layoutSubviews, thanks to https://medium.com/@ssamadgh/designing-apps-with-scroll-views-part-i-8a7a44a5adf7
            // Sometimes this seems to work (view animates size and position simultaneously from current position to center) and sometimes it does not (position snaps to center immediately, size change animates)
            scrollView.centerContent()
        }

        override func viewWillTransition(to _: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            coordinator.animate { [self] _ in
                scrollView.zoom(to: hostedView.bounds, animated: false)

            }
        }

        func viewForZooming(in _: UIScrollView) -> UIView? {
            return hostedView
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }
    }
}
