//
//  MapWith.swift
//  ScotTraffic
//
//  Created by Neil Gall on 08/03/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation

// MappedWith transforms a signal combined with the latest value of another signal
//
class MappedWith1<Source: SignalType, WithSource: SignalType, MappedType> : Signal<MappedType> {
    private let source: Source
    private let withSource: WithSource
    private let transform: (Source.ValueType, WithSource.ValueType) -> MappedType
    private var receiver: ReceiverType!
    
    init(_ source: Source, withSource: WithSource, transform: (Source.ValueType, WithSource.ValueType) -> MappedType) {
        self.source = source
        self.withSource = withSource
        self.transform = transform
        
        super.init()
        
        self.receiver = Receiver(source) { [weak self] transaction in
            switch transaction {
            case .Begin:
                self?.pushTransaction(.Begin)
            case .End(let sourceValue):
                if let withValue = withSource.latestValue.get {
                    self?.pushTransaction(.End(transform(sourceValue, withValue)))
                } else {
                    self?.pushTransaction(.Cancel)
                }
            case .Cancel:
                self?.pushTransaction(.Cancel)
            }
        }
    }
    
    override var latestValue: LatestValue<MappedType> {
        switch source.latestValue {
        case .None:
            return .None
        case .Stored(let sourceValue):
            if let withValue = withSource.latestValue.get {
                return .Computed({ self.transform(sourceValue, withValue) })
            } else {
                return .None
            }
        case .Computed(let getSourceValue):
            if let withValue = withSource.latestValue.get {
                return .Computed({ self.transform(getSourceValue(), withValue) })
            } else {
                return .None
            }
        }
    }
}

class MappedWith2<Source: SignalType, S1: SignalType, S2: SignalType, MappedType> : Signal<MappedType> {
    private let source: Source
    private let withSource1: S1
    private let withSource2: S2
    private let transform: (Source.ValueType, S1.ValueType, S2.ValueType) -> MappedType
    private var receiver: ReceiverType!
    
    init(_ source: Source, with1: S1, with2: S2, transform: (Source.ValueType, S1.ValueType, S2.ValueType) -> MappedType) {
        self.source = source
        self.withSource1 = with1
        self.withSource2 = with2
        self.transform = transform
        
        super.init()
        
        self.receiver = Receiver(source) { [weak self] transaction in
            switch transaction {
            case .Begin:
                self?.pushTransaction(.Begin)
            case .End(let sourceValue):
                if let withValue1 = with1.latestValue.get, withValue2 = with2.latestValue.get {
                    self?.pushTransaction(.End(transform(sourceValue, withValue1, withValue2)))
                } else {
                    self?.pushTransaction(.Cancel)
                }
            case .Cancel:
                self?.pushTransaction(.Cancel)
            }
        }
    }
    
    override var latestValue: LatestValue<MappedType> {
        switch source.latestValue {
        case .None:
            return .None
        case .Stored(let sourceValue):
            if let withValue1 = withSource1.latestValue.get, withValue2 = withSource2.latestValue.get {
                return .Computed({ self.transform(sourceValue, withValue1, withValue2) })
            } else {
                return .None
            }
        case .Computed(let getSourceValue):
            if let withValue1 = withSource1.latestValue.get, withValue2 = withSource2.latestValue.get {
                return .Computed({ self.transform(getSourceValue(), withValue1, withValue2) })
            } else {
                return .None
            }
        }
    }
}

extension SignalType {
    public func mapWith<WithSignal: SignalType, TargetType>(with: WithSignal, transform: (ValueType, WithSignal.ValueType) -> TargetType) -> Signal<TargetType> {
        return MappedWith1(self, withSource: with, transform: transform)
    }

    public func mapWith<S1: SignalType, S2: SignalType, TargetType>(with: S1, _ with2: S2, transform: (ValueType, S1.ValueType, S2.ValueType) -> TargetType) -> Signal<TargetType> {
        return MappedWith2(self, with1: with, with2: with2, transform: transform)
    }
}