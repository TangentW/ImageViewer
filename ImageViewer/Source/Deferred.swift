//
//  Deferred.swift
//  ImageViewer
//
//  Created by Tangent on 2018/11/15.
//  Copyright © 2018 MailOnline. All rights reserved.
//

final class Deferred<T> {
    
    typealias Callback = (T) -> ()
    
    private var _callback: Callback?
    
    init(_ initial: T) { value = initial }
    
    var value: T {
        didSet { _callback?(value) }
    }
    
    func setupCallback(_ callback: @escaping Callback) {
        _callback = callback
        
        // Replay latest value
        callback(value)
    }

    func clear() {
        _callback = nil
    }
}
