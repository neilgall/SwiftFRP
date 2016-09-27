//
//  Types.swift
//  SwiftFRP
//
//  Created by Neil Gall on 04/01/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation

// Marker protocol for objects which can receive values from signals.
//
public protocol ReceiverType {}

// Signal changes are propagated using multi-phase transactions. A Begin is always
// sent, followed by an End with a new Value or a Cancel.
//
public enum Transaction<ValueType> {
    case begin
    case end(ValueType)
    case cancel
}

// Some Signals can supply their latest value, which is always wrapped in this type.
// None means there is no latest value. Computed means the signal can supply a value
// but it is computed using the signal's function and possibly further upstream functions.
// The value is therefore supplied lazily. Stored supplies the value directly.
//
public enum LatestValue<Value> {
    case none
    case computed((Void) -> Value)
    case stored(Value)
    
    public var has: Bool {
        switch self {
        case .none: return false
        case .stored: return true
        case .computed: return true
        }
    }
    
    public var get: Value? {
        switch self {
        case .none:
            return nil
        case .stored(let value):
            return value
        case .computed(let getValue):
            return getValue()
        }
    }
}

// Base interface for Signals. Observers are just closures which receive transactions
// from the signal. Adding an observer returns a unique identifier which can be used
// later to remove it. Changes are pushed directly with pushValue() or in phases with
// pushTransaction()
//
public protocol SignalType {
    associatedtype ValueType
    associatedtype Observer = Int
    
    func addObserver(_ observer: @escaping (Transaction<ValueType>) -> Void) -> Observer
    func removeObserver(_ id: Observer)
    
    func pushTransaction(_ transaction: Transaction<ValueType>)
    func pushValue(_ value: ValueType)
    
    var latestValue: LatestValue<ValueType> { get }
}

// An Input is a signal whose value can be mutated directly.
//
public protocol InputType: class {
    associatedtype ValueType
    
    var value: ValueType { get set }
}

// Standard SignalType implementation.
//
public class Signal<Value> : SignalType {
    public typealias ValueType = Value
    
    private var observers = KeyedSet<(Transaction<ValueType>) -> Void>()
    
    public init() {
    }
    
    open func addObserver(_ observer: @escaping (Transaction<ValueType>) -> Void) -> Int {
        switch latestValue {
        case .stored(let value):
            observer(.begin)
            observer(.end(value))
        case .computed(let getValue):
            observer(.begin)
            observer(.end(getValue()))
        case .none:
            break
        }
        return observers.add(observer)
    }
    
    open func removeObserver(_ id: Int) {
        observers.remove(id)
    }
    
    // Push
    open func pushValue(_ value: ValueType) {
        pushTransaction(.begin)
        pushTransaction(.end(value))
    }
    
    open func pushTransaction(_ transaction: Transaction<ValueType>) {
        for observer in observers {
            observer(transaction)
        }
    }
    
    open var latestValue: LatestValue<Value> {
        return .none
    }
}

// Standard InputType implementation
//
public class Input<Value>: Signal<Value>, InputType {
    public typealias ValueType = Value
    
    open var value: Value {
        willSet {
            assert(!inTransaction)
        }
        didSet {
            inTransaction = true
            pushValue(value)
            inTransaction = false
        }
    }

    override open var latestValue: LatestValue<Value> {
        return .stored(value)
    }
    
    private var inTransaction: Bool = false
    
    public init(initial: Value) {
        value = initial
    }
    
    open func modify(_ transform: (Value) -> Value) {
        value = transform(value)
    }
}

// A ComputedSignal cannot propagate changes, but stores a closure which is returned
// by latestValue. Implements a signal value which changes over time.
//
public class ComputedSignal<Value>: Signal<Value> {
    private let compute: () -> Value

    public init(_ compute: @escaping () -> Value) {
        self.compute = compute
    }
    
    override open var latestValue: LatestValue<Value> {
        return .computed(compute)
    }
}

// A Transaction receiver. Initialise with a source signal and a closure which is invoked
// on transactions from that signal.
//
class Receiver<Source: SignalType>: ReceiverType {
    typealias ValueType = Source.ValueType
    
    private let source: Source
    private let observer: Source.Observer
    
    init(_ source: Source, _ closure: @escaping (Transaction<Source.ValueType>) -> Void) {
        self.source = source
        self.observer = source.addObserver(closure)
    }
    
    deinit {
        source.removeObserver(observer)
    }
}

// An Output is the opposite of an Input. It is a receiver which only responds to the End
// transaction, unwrapping the value and passing it to a closure.
//
public class Output<Source: SignalType>: Receiver<Source> {
    public init(_ source: Source, _ closure: @escaping (Source.ValueType) -> Void) {
        super.init(source) { transaction in
            if case .end(let value) = transaction {
                closure(value)
            }
        }
    }
}

// A WillOutput is like an Output but responds to the Begin phase of a signal change.
//
public class WillOutput<Source: SignalType>: Receiver<Source> {
    public init(_ source: Source, _ closure: @escaping (Void) -> Void) {
        super.init(source) { transaction in
            if case .begin = transaction {
                closure()
            }
        }
    }
}
