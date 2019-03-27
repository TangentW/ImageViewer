//
//  BlurView.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 01/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit

class BlurView: UIView {

    var blurPresentAnimationStyle: AnimationStyle = .custom(duration: 0.5, delay: 0)

    var colorPresentAnimationStyle: AnimationStyle = .custom(duration: 0.25, delay: 0)

    var blurDismissAnimationStyle: AnimationStyle = .none

    var colorDismissAnimationStyle: AnimationStyle = .none

    var blurTargetOpacity: CGFloat = 1
    var colorTargetOpacity: CGFloat = 1

    var overlayColor = UIColor.black {
        didSet { colorView.backgroundColor = overlayColor }
    }

    let blurringViewContainer = UIView() //serves as a transparency container for the blurringView as it's not recommended by Apple to apply transparency directly to the UIVisualEffectsView
    let blurringView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    let colorView = UIView()

    convenience init() {

        self.init(frame: CGRect.zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        blurringViewContainer.alpha = 0

        colorView.backgroundColor = overlayColor
        colorView.alpha = 0

        self.addSubview(blurringViewContainer)
        blurringViewContainer.addSubview(blurringView)
        self.addSubview(colorView)
    }

    @available (iOS, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()

        blurringViewContainer.frame = self.bounds
        blurringView.frame = blurringViewContainer.bounds
        colorView.frame = self.bounds
    }

    func present() {

        blurDismissAnimationStyle.excute(animations: { [weak self] in
            self?.blurringViewContainer.alpha = self!.blurTargetOpacity
        })

        colorPresentAnimationStyle.excute(animations: { [weak self] in
            self?.colorView.alpha = self!.colorTargetOpacity
        })
    }

    func dismiss() {

        blurDismissAnimationStyle.excute(animations: { [weak self] in
            self?.blurringViewContainer.alpha = 0
        })

        colorDismissAnimationStyle.excute(animations: { [weak self] in
            self?.colorView.alpha = 0
        })
    }
}
