//
//  Sequences.swift
//  ScotTraffic
//
//  Created by Neil Gall on 04/01/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation

// Convenience map, filter and reduce operations on the values inside signals containing sequences
//
public extension Signal where Value: SequenceType {

    public func mapSeq<TargetType>(transform: Value.Generator.Element -> TargetType) -> Signal<[TargetType]> {
        return map({ $0.map(transform) })
    }
    
    public func filterSeq(predicate: Value.Generator.Element -> Bool) -> Signal<[Value.Generator.Element]> {
        return map({ $0.filter(predicate) })
    }
    
    public func reduceSeq<TargetType>(initial: TargetType, combine: (TargetType, Value.Generator.Element) -> TargetType) -> Signal<TargetType> {
        return map({ $0.reduce(initial, combine: combine) })
    }
}