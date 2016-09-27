//
//  Booleans.swift
//  SwiftFRP
//
//  Created by Neil Gall on 04/01/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation

public protocol BooleanType {
    var boolValue: Bool { get }
}

extension Bool: BooleanType {
    public var boolValue: Bool {
        return self
    }
}

// Gate is a form of controllable filter. Values from the source signal are not
// propagated when the gate is "closed" (false). When the gate opens, the last
// value frm the source signal is then propagated.
//
class Gate<Source: SignalType, Gate: SignalType> : Signal<Source.ValueType> where Gate.ValueType: BooleanType {
    let gateLatest: Signal<Gate.ValueType>
    var valueLatest: Source.ValueType?
    var receivers: [ReceiverType] = []
    var transactionCount = 0
    
    init(_ source: Source, gate: Gate) {
        gateLatest = gate.latest()
        super.init()
        
        receivers.append(Receiver(source) { [weak self] in
            switch $0 {
            case .begin:
                self?.beginTransaction()
                self?.valueLatest = nil
            case .end(let value):
                self?.valueLatest = value
                self?.endTransaction()
            case .cancel:
                self?.endTransaction()
            }
        })
        
        receivers.append(Receiver(gateLatest) { [weak self] in
            switch $0 {
            case .begin:
                self?.beginTransaction()
            case .end, .cancel:
                self?.endTransaction()
            }
        })
    }

    private func beginTransaction() {
        if transactionCount == 0 {
            pushTransaction(.begin)
        }
        transactionCount += 1
    }
    
    private func endTransaction() {
        transactionCount -= 1
        if transactionCount == 0 {
            if let value = valueLatest, let gate = gateLatest.latestValue.get , gate.boolValue {
                pushTransaction(.end(value))
                valueLatest = nil
            } else {
                pushTransaction(.cancel)
            }
        }
    }
}

extension Signal where Value: BooleanType, Value: Equatable {

    // An output on boolean signals which only fire when the value goes from false to true
    //
    public func onRisingEdge(_ closure: @escaping (Void) -> Void) -> ReceiverType {
        return onChange().filter({ $0.boolValue == true }) --> { _ in closure() }
    }
    
    // An output on boolean signals which only fire when the value goes from true to false
    //
    public func onFallingEdge(_ closure: @escaping (Void) -> Void) -> ReceiverType {
        return onChange().filter({ $0.boolValue == false }) --> { _ in closure() }
    }
    
    // Convenience Gate creation
    //
    public func gate<SourceType>(_ source: Signal<SourceType>) -> Signal<SourceType> {
        return Gate(source, gate: self.map({ $0.boolValue }))
    }
}

// Invert the sense of a boolean signal
//
public func not<S: SignalType>(_ signal: S) -> Signal<Bool> where S.ValueType: BooleanType {
    return signal.map { b in !b.boolValue }
}

// Given a signal where the value type is optional, create a signal that indicates whether
// the source value is nil
//
public func isNil<S: SignalType, T>(_ signal: S) -> Signal<Bool> where S.ValueType == T? {
    return signal.map { $0 == nil }
}

// Logical AND of boolean signals. Note that there is no shortcutting as this is based on
// Combiners, so both sides are evaluated on each change.
//
public func && <LHS: SignalType, RHS: SignalType>(lhs: LHS, rhs: RHS) -> Signal<Bool> where LHS.ValueType: BooleanType, RHS.ValueType: BooleanType {
    return combine(lhs, rhs) { $0.boolValue && $1.boolValue }
}

// Logical OR of boolean signals. Note that there is no shortcutting as this is based on
// Combiners, so both sides are evaluated on each change.
//
public func || <LHS: SignalType, RHS: SignalType>(lhs: LHS, rhs: RHS) -> Signal<Bool> where LHS.ValueType: BooleanType, RHS.ValueType: BooleanType {
    return combine(lhs, rhs) { $0.boolValue || $1.boolValue }
}

