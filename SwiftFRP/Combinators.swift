//
//  Combinators.swift
//  SwiftFRP
//
//  Created by Neil Gall on 30/09/2015.
//  Copyright © 2015 Neil Gall. All rights reserved.
//

import Foundation

// Never is a signal which never propagates any value. Useful as starting points for reduces, etc.
//
public class Never<Value> : Signal<Value> {
}

// Const is a signal which never propagates a new value but responds to latestValue with a constant.
// Also useful as starting points for reduces, etc.
//
public class Const<Value> : Signal<Value> {
    public let value: Value

    public init(_ value: Value) {
        self.value = value
    }
    
    override public var latestValue: LatestValue<Value> {
        return .stored(value)
    }
}

// Event only propagates value changes, hiding the latestValue from any underlying signal
//
class Event<Source: SignalType> : Signal<Source.ValueType> {
    private var receiver: ReceiverType!
    
    init(_ source: Source) {
        super.init()
        receiver = Receiver(source) { [weak self] transaction in
            self?.pushTransaction(transaction)
        }
    }
}

// Filter only propagates values from a source signal which satisfy a predicate. Transactions
// which fail the predicate are cancelled.
//
class Filter<Source: SignalType> : Signal<Source.ValueType> {
    private var receiver: ReceiverType!
    
    init(_ source: Source, _ predicate: @escaping (Source.ValueType) -> Bool) {
        super.init()
        receiver = Receiver(source) { [weak self] transaction in
            if case .end(let value) = transaction , !predicate(value) {
                self?.pushTransaction(.cancel)
            } else {
                self?.pushTransaction(transaction)
            }
        }
    }
}

// Mapped transforms a source signal using a pure, total function. latestValue returns
// a Computed using the same function.
//
class Mapped<Source: SignalType, MappedType> : Signal<MappedType> {
    private let source: Source
    private let transform: (Source.ValueType) -> MappedType
    private var receiver: ReceiverType!
    
    init(_ source: Source, _ transform: @escaping (Source.ValueType) -> MappedType) {
        self.source = source
        self.transform = transform
        
        super.init()
        
        self.receiver = Receiver(source) { [weak self] transaction in
            switch transaction {
            case .begin:
                self?.pushTransaction(.begin)
            case .end(let sourceValue):
                self?.pushTransaction(.end(transform(sourceValue)))
            case .cancel:
                self?.pushTransaction(.cancel)
            }
        }
    }
    
    override var latestValue: LatestValue<MappedType> {
        switch source.latestValue {
        case .none:
            return .none
        case .stored(let sourceValue):
            return .computed({ self.transform(sourceValue) })
        case .computed(let getSourceValue):
            return .computed({ self.transform(getSourceValue()) })
        }
    }
}

// Union combines values from multiple signals of the same type into a single stream.
//
class Union<Source: SignalType> : Signal<Source.ValueType> {
    private var receivers: [ReceiverType]!
    
    init(_ sources: [Source]) {
        super.init()
        self.receivers = sources.map { [weak self] in
            Receiver($0) {
                self?.pushTransaction($0)
            }
        }
    }
}

// WrappedSignal just propagates the source signal. It is really a workaround for the
// fact that SignalType cannot be used as a type in Swift.
//
class WrappedSignal<Source: SignalType>: Signal<Source.ValueType> {
    private let source: Source
    private var receiver: ReceiverType!
    
    init(_ source: Source) {
        self.source = source
        
        super.init()
        
        self.receiver = Receiver(source) { [weak self] in
            self?.pushTransaction($0)
        }
    }
    
    override var latestValue: LatestValue<Source.ValueType> {
        return source.latestValue
    }
}

// Latest is like WrappedSignal but also stores the latest value of its source.
//
public class Latest<Source: SignalType>: Signal<Source.ValueType> {
    let source: Source
    var value: Source.ValueType?
    private var receiver: ReceiverType!
    
    init(_ source: Source) {
        self.source = source
        self.value = source.latestValue.get
        
        super.init()

        self.receiver = Receiver(source) { [weak self] transaction in
            if case .end(let value) = transaction {
                self?.value = value
            }
            self?.pushTransaction(transaction)
        }
    }
    
    override public var latestValue: LatestValue<Source.ValueType> {
        if let value = value {
            return .stored(value)
        } else {
            return .none
        }
    }
}

// OnChange can be used with Equatable value types and only propagates changes which are not
// equal to the previous value. Upstream notifications with the same value are cancelled. OnChange
// is consequently also a Latest since the previous value must be stored.
//
class OnChange<Source: SignalType> : Signal<Source.ValueType> where Source.ValueType: Equatable {
    private var receiver: ReceiverType!
    private var value: Source.ValueType?
    
    init(_ source: Source) {
        super.init()
        value = source.latestValue.get
        receiver = Receiver(source) { [weak self] transaction in
            if case .end(let newValue) = transaction {
                if newValue == self?.value {
                    self?.pushTransaction(.cancel)
                } else {
                    self?.value = newValue
                    self?.pushTransaction(transaction)
                }
            } else {
                self?.pushTransaction(transaction)
            }
        }
    }
    
    override var latestValue: LatestValue<Source.ValueType> {
        guard let value = value else {
            return .none
        }
        return .stored(value)
    }
}

// Syntactical sugar for creating an Output. With the core of the signal network purely
// functional, it is useful to have distinctive syntax for the imperative inputs and outputs.
//
infix operator -->: AssignmentPrecedence

public func --> <Source: SignalType> (source: Source, closure: @escaping (Source.ValueType) -> Void) -> ReceiverType {
    return Output(source, closure)
}

// Syntactical sugar for assigning a value to an input
//
infix operator <--: AssignmentPrecedence

public func <-- <Input: InputType, ValueType> (input: Input, value: ValueType) where Input.ValueType == ValueType {
    input.value = value
}

// Helper methods for creating derived signals
//
extension SignalType {
    public func willOutput(_ closure: @escaping (Void) -> Void) -> WillOutput<Self> {
        return WillOutput(self, closure)
    }
    
    public func signal() -> Signal<ValueType> {
        return WrappedSignal(self)
    }
    
    public func event() -> Signal<ValueType> {
        return Event(self)
    }
    
    public func latest() -> Signal<ValueType> {
        // if the source signal can already provide a stored value, there's no point wrapping it in a Latest
        if let signal = self as? Signal<ValueType>, case .stored = signal.latestValue {
            return signal
        }
        
        return Latest(self)
    }
    
    public func map<TargetType>(_ transform: @escaping (ValueType) -> TargetType) -> Signal<TargetType> {
        return Mapped(self, transform)
    }
    
    public func filter(_ predicate: @escaping (ValueType) -> Bool) -> Signal<ValueType> {
        return Filter(self, predicate)
    }
}

extension SignalType where ValueType: Equatable {
    public func onChange() -> Signal<ValueType> {
        return OnChange(self)
    }
}

public func union<Source: SignalType>(_ sources: Source...) -> Signal<Source.ValueType> {
    return Union(sources)
}

public func notNil<S: SignalType, T>(_ signal: S) -> Signal<T> where S.ValueType == T? {
    return signal.filter({ $0 != nil }).map({ $0! })
}
