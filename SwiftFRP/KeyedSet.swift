//
//  KeyedSet.swift
//  ScotTraffic
//
//  Created by Neil Gall on 13/03/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation

public struct KeyedSet<Element>: SequenceType {
    public typealias Key = Int
    public typealias Generator = LazyMapCollection<[Key: Element], Element>.Generator

    private var items: [Key: Element] = [:]
    private var nextItemKey: Key = 0
    
    public mutating func add(element: Element) -> Key {
        let key = newItemKey()
        items[key] = element
        return key
    }
    
    public mutating func remove(key: Key) {
        items.removeValueForKey(key)
    }
    
    public func generate() -> Generator {
        return items.values.generate()
    }
    
    private mutating func newItemKey() -> Key {
        let key = nextItemKey
        nextItemKey += 1
        return key
    }
}
