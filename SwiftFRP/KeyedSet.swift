//
//  KeyedSet.swift
//  SwiftFRP
//
//  Created by Neil Gall on 13/03/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation

public struct KeyedSet<Element>: Sequence {
    public typealias Key = Int
    public typealias Iterator = LazyMapCollection<[Key: Element], Element>.Iterator

    private var items: [Key: Element] = [:]
    private var nextItemKey: Key = 0
    
    public mutating func add(_ element: Element) -> Key {
        let key = newItemKey()
        items[key] = element
        return key
    }
    
    public mutating func remove(_ key: Key) {
        items.removeValue(forKey: key)
    }
    
    public func makeIterator() -> Iterator {
        return items.values.makeIterator()
    }
    
    private mutating func newItemKey() -> Key {
        let key = nextItemKey
        nextItemKey += 1
        return key
    }
}
