//
//  Join.swift
//  ScotTraffic
//
//  Created by Neil Gall on 04/01/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation

// Monad join (flatten) operation on nested signals. Given a Signal<Signal<A>>, join()
// yields a Signal<A> which propagates whenever either layer of signal changes.
//
class JoinedSignal<Value>: Signal<Value> {
    
    private var outerReceiver: ReceiverType!
    private var innerReceiver: ReceiverType?
    private var innerSignal: Signal<Value>?
    
    init<Outer: SignalType, Inner: SignalType where Outer.ValueType == Inner, Inner.ValueType == Value>(_ source: Outer) {
        super.init()
        outerReceiver = Receiver(source) { [weak self] transaction in
            if case .End(let inner) = transaction {
                self?.innerSignal = inner.signal()
                self?.innerReceiver = Receiver(inner) { [weak self] transaction in
                    self?.pushTransaction(transaction)
                }
            }
        }
    }
    
    override var latestValue: LatestValue<Value> {
        guard let innerSignal = innerSignal else {
            return .None
        }
        return innerSignal.latestValue
    }
}

public extension SignalType where ValueType: SignalType {
    public func join() -> Signal<ValueType.ValueType> {
        return JoinedSignal(self)
    }
}
