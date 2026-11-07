import SwiftUI
import UIKit
import ObjectiveC

// SwiftUI's TabView doesn't report a tap on the already-selected tab. This installs a
// delegate proxy on the underlying UITabBarController to detect it, and offers the
// scroll-to-top that a second tap performs when the tab is already at its root.

/// Calls `onReselect` with the tab index when the user taps the tab that is already selected.
struct TabReselectionObserver: UIViewControllerRepresentable {
    let onReselect: (Int) -> Void

    func makeUIViewController(context: Context) -> TabReselectionInstallerViewController {
        TabReselectionInstallerViewController(onReselect: onReselect)
    }

    func updateUIViewController(
        _ uiViewController: TabReselectionInstallerViewController,
        context: Context
    ) {
        uiViewController.onReselect = onReselect
        uiViewController.installIfNeeded()
    }
}

enum TabBarScrollToTop {
    /// Scrolls the first scrollable view in the selected tab back to its top.
    @MainActor
    static func scrollSelectedTab() {
        let tabController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .compactMap(\.rootViewController)
            .compactMap { $0.findTabBarController() }
            .first

        guard
            let rootView = tabController?.selectedViewController?.view,
            let scrollView = rootView.firstScrollableDescendant()
        else { return }

        let topOffset = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
        scrollView.setContentOffset(topOffset, animated: true)
    }
}

final class TabReselectionInstallerViewController: UIViewController {
    var onReselect: (Int) -> Void
    private var proxy: TabBarDelegateProxy?

    init(onReselect: @escaping (Int) -> Void) {
        self.onReselect = onReselect
        super.init(nibName: nil, bundle: nil)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installIfNeeded()
    }

    func installIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let tabBarController = self.tabBarController
            else { return }

            if let proxy = self.proxy, tabBarController.delegate === proxy {
                return
            }

            let proxy = TabBarDelegateProxy(
                original: tabBarController.delegate,
                onReselect: { [weak self] index in
                    self?.onReselect(index)
                }
            )
            self.proxy = proxy
            tabBarController.delegate = proxy
        }
    }
}

private final class TabBarDelegateProxy: NSObject, UITabBarControllerDelegate {
    weak var original: UITabBarControllerDelegate?
    let onReselect: (Int) -> Void

    init(
        original: UITabBarControllerDelegate?,
        onReselect: @escaping (Int) -> Void
    ) {
        self.original = original
        self.onReselect = onReselect
        super.init()
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        let shouldSelect = original?.tabBarController?(
            tabBarController,
            shouldSelect: viewController
        ) ?? true

        if shouldSelect,
           viewController === tabBarController.selectedViewController,
           let index = tabBarController.viewControllers?.firstIndex(of: viewController) {
            DispatchQueue.main.async { [onReselect] in
                onReselect(index)
            }
        }

        return shouldSelect
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original, original.responds(to: aSelector) {
            return original
        }
        return super.forwardingTarget(for: aSelector)
    }
}

private extension UIView {
    func firstScrollableDescendant() -> UIScrollView? {
        if let scrollView = self as? UIScrollView,
           scrollView.isScrollEnabled,
           !scrollView.isHidden,
           scrollView.alpha > 0 {
            return scrollView
        }

        for subview in subviews {
            if let scrollView = subview.firstScrollableDescendant() {
                return scrollView
            }
        }

        return nil
    }
}

private extension UIViewController {
    func findTabBarController() -> UITabBarController? {
        if let t = self as? UITabBarController { return t }
        if let nav = self as? UINavigationController {
            for vc in nav.viewControllers {
                if let t = vc.findTabBarController() { return t }
            }
        }
        for child in children {
            if let t = child.findTabBarController() { return t }
        }
        if let presented = presentedViewController {
            return presented.findTabBarController()
        }
        return nil
    }
}
