//
//  Sink.swift
//  Rx
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

struct Sink_<ElementType>: ObserverType {
    typealias Element = ElementType
    
    let sink: Sink<Element>
    
    init(sink: Sink<Element>) {
        self.sink = sink
    }
    
    mutating func on(event: Event<Element>) -> Result<Void> {
        let result = sink.state.observer.on(event)
        switch event {
        case .Next:
            return result
        case .Completed: fallthrough
        case .Error:
            self.sink.dispose()
            return result
        }
    }
}

class Sink<ElementType> :  Disposable {
    private typealias Element = ElementType
    
    typealias State = (observer: ObserverOf<ElementType>, cancel: Disposable, disposed: Bool)
    
    private var lock = Lock()
    private var _state: State
    
    var observer: ObserverOf<ElementType> {
        get {
            return lock.calculateLocked { _state.observer }
        }
    }
    
    var cancel: Disposable {
        get {
            return lock.calculateLocked { _state.cancel }
        }
    }
    
    var state: State {
        get {
            return lock.calculateLocked { _state }
        }
    }
    
    init(observer: ObserverOf<ElementType>, cancel: Disposable) {
#if DEBUG
        OSAtomicIncrement32(&resourceCount)
#endif
        _state = (
            observer: observer,
            cancel: cancel,
            disposed: false
        )
    }
    
    func getForwarder() -> Sink_<Element> {
        return Sink_(sink: self)
    }
    
    func dispose() {
        var cancel: Disposable? = lock.calculateLocked {
            if _state.disposed {
                return nil
            }
            
            var cancel = _state.cancel
            
            _state.disposed = true
            _state.observer = ObserverOf(NopObserver())
            _state.cancel = DefaultDisposable()
            
            return cancel
        }
        
        if let cancel = cancel {
            cancel.dispose()
        }
    }
    
    deinit {
#if DEBUG
        OSAtomicDecrement32(&resourceCount)
#endif
    }
}