//
//  Sequences.swift
//  SwiftFRP
//
//  Created by Neil Gall on 04/01/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation

// Convenience map, filter and reduce operations on the values inside signals containing sequences
//
public extension Signal where Value: Sequence {

    public func mapSeq<TargetType>(_ transform: @escaping (Value.Iterator.Element) -> TargetType) -> Signal<[TargetType]> {
        return map({ $0.map(transform) })
    }
    
    public func filterSeq(_ predicate: @escaping (Value.Iterator.Element) -> Bool) -> Signal<[Value.Iterator.Element]> {
        return map({ $0.filter(predicate) })
    }
    
    public func reduceSeq<TargetType>(_ initial: TargetType, combine: @escaping (TargetType, Value.Iterator.Element) -> TargetType) -> Signal<TargetType> {
        return map({ $0.reduce(initial, combine) })
    }
}
