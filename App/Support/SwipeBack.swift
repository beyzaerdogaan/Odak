import UIKit

/// Pushed screens hide the navigation bar and draw their own back button,
/// which makes UIKit switch off the edge swipe that pops a screen. Taking
/// over the gesture's delegate turns it back on for every navigation stack.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    /// Only swipe when there is a screen to go back to; on the root the
    /// gesture would leave the stack stuck mid-transition.
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === interactivePopGestureRecognizer && viewControllers.count > 1
    }
}
