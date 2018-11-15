//
//  ImageViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 01/08/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit
import AVFoundation


extension VideoView: ItemView {}

class VideoViewController: ItemBaseController<VideoView> {

    fileprivate let swipeToDismissFadeOutAccelerationFactor: CGFloat = 6
    
    fileprivate let fetchVideoURLBlock: FetchVideoURLBlock
    private var _player: AVPlayer? {
        didSet { playerDeferred.value = _player }
    }
    
    let playerDeferred = Deferred<AVPlayer?>(nil)

    unowned let scrubber: VideoScrubber

    let fullHDScreenSizeLandscape = CGSize(width: 1920, height: 1080)
    let fullHDScreenSizePortrait = CGSize(width: 1080, height: 1920)
    let embeddedPlayButton = UIButton.circlePlayButton(70)
    
    private var autoPlayStarted: Bool = false
    private var autoPlayEnabled: Bool = false

    init(index: Int, itemCount: Int, fetchImageBlock: @escaping FetchImageBlock, fetchVideoURLBlock: @escaping FetchVideoURLBlock, scrubber: VideoScrubber, configuration: GalleryConfiguration, isInitialController: Bool = false) {

        self.fetchVideoURLBlock = fetchVideoURLBlock
        self.scrubber = scrubber

        ///Only those options relevant to the paging VideoViewController are explicitly handled here, the rest is handled by ItemViewControllers
        for item in configuration {
            
            switch item {
                
            case .videoAutoPlay(let enabled):
                autoPlayEnabled = enabled
                
            default: break
            }
        }

        super.init(index: index, itemCount: itemCount, fetchImageBlock: fetchImageBlock, configuration: configuration, isInitialController: isInitialController)
    }
    
    @objc func fetchVideoURLAndPlayerIfNeeds() {
        UIView.animate(withDuration: 0.25, animations: { [weak self] in
            
            self?.embeddedPlayButton.alpha = 0
            
        }, completion: { [weak self] _ in
                
            self?.embeddedPlayButton.isHidden = true
        })
        
        if let player = _player { player.play(); return }
        
        let loadingView: UIView =  {
            let loading = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
            loading.center = .init(x: 0.5 * view.bounds.width, y: 0.5 * view.bounds.height)
            loading.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
            loading.startAnimating()
            return loading
        }()
        view.addSubview(loadingView)

        fetchVideoURLBlock { [weak self, weak loadingView] url in
            
            guard let url = url else { return }
            
            DispatchQueue.main.async {
                loadingView?.removeFromSuperview()
                self?._setupPlayer(with: url)
                self?._player?.play()
            }
        }
    }
    
    private func _setupPlayer(with url: URL) {
        
        let player = AVPlayer(url: url)
        player.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)
        itemView.player = player
        _player = player
    }
    
    private func _addObserversForPlayer() {
        
        _removeObserversForPlayer()
        
        _player?.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        _player?.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    private func _removeObserversForPlayer() {
        
        _player?.removeObserver(self, forKeyPath: "status")
        _player?.removeObserver(self, forKeyPath: "rate")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if isInitialController == true { embeddedPlayButton.alpha = 0 }

        embeddedPlayButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleBottomMargin, .flexibleRightMargin]
        self.view.addSubview(embeddedPlayButton)
        embeddedPlayButton.center = self.view.boundsCenter

        embeddedPlayButton.addTarget(self, action: #selector(fetchVideoURLAndPlayerIfNeeds), for: UIControl.Event.touchUpInside)

        self.itemView.contentMode = .scaleAspectFill
    }

    override func viewWillAppear(_ animated: Bool) {
        
        _addObserversForPlayer()

        UIApplication.shared.beginReceivingRemoteControlEvents()

        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {

        _removeObserversForPlayer()

        UIApplication.shared.endReceivingRemoteControlEvents()

        super.viewWillDisappear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        performAutoPlay()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        _player?.pause()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let isLandscape = itemView.bounds.width >= itemView.bounds.height
        itemView.bounds.size = aspectFitSize(forContentOfSize: isLandscape ? fullHDScreenSizeLandscape : fullHDScreenSizePortrait, inBounds: self.scrollView.bounds.size)
        itemView.center = scrollView.boundsCenter
    }

    override func closeDecorationViews(_ duration: TimeInterval) {

        UIView.animate(withDuration: duration, animations: { [weak self] in

            self?.embeddedPlayButton.alpha = 0
            self?.itemView.previewImageView.alpha = 1
        })
    }

    override func presentItem(alongsideAnimation: () -> Void, completion: @escaping () -> Void) {

        let circleButtonAnimation = {

            UIView.animate(withDuration: 0.15, animations: { [weak self] in
                self?.embeddedPlayButton.alpha = 1
            })
        }

        super.presentItem(alongsideAnimation: alongsideAnimation) {

            circleButtonAnimation()
            completion()
        }
    }

    override func displacementTargetSize(forSize size: CGSize) -> CGSize {

        let isLandscape = itemView.bounds.width >= itemView.bounds.height
        return aspectFitSize(forContentOfSize: isLandscape ? fullHDScreenSizeLandscape : fullHDScreenSizePortrait, inBounds: rotationAdjustedBounds().size)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if keyPath == "rate" || keyPath == "status" {

            fadeOutEmbeddedPlayButton()
        }

        else if keyPath == "contentOffset" {

            handleSwipeToDismissTransition()
        }

        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }

    func handleSwipeToDismissTransition() {

        guard let _ = swipingToDismiss else { return }

        embeddedPlayButton.center.y = view.center.y - scrollView.contentOffset.y
    }

    func fadeOutEmbeddedPlayButton() {
        
        guard let player = _player else { return }

        if player.isPlaying() && embeddedPlayButton.alpha != 0  {

            UIView.animate(withDuration: 0.3, animations: { [weak self] in

                self?.embeddedPlayButton.alpha = 0
            })
        }
    }

    override func remoteControlReceived(with event: UIEvent?) {
        
        guard let player = _player else { return }

        if let event = event {

            if event.type == UIEventType.remoteControl {

                switch event.subtype {

                case .remoteControlTogglePlayPause:

                    if player.isPlaying()  {

                        player.pause()
                    }
                    else {

                        player.play()
                    }

                case .remoteControlPause:

                    player.pause()

                case .remoteControlPlay:

                    player.play()

                case .remoteControlPreviousTrack:

                    player.pause()
                    player.seek(to: CMTime(value: 0, timescale: 1))
                    player.play()

                default:

                    break
                }
            }
        }
    }
    
    private func performAutoPlay() {
        guard autoPlayEnabled else { return }
        guard autoPlayStarted == false else { return }
        
        autoPlayStarted = true
        embeddedPlayButton.isHidden = true
        scrubber.play()
    }
}
