//
//  FRPJoinTests.swift
//  SwiftFRP
//
//  Created by Neil Gall on 04/01/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import XCTest
@testable import SwiftFRP

// Must be a class so it can be mutated inside the receiver closure
private class Capture<T> {
    var receivers = [ReceiverType]()
    var vals: [T] = []
    
    init(_ o: Signal<T>, previous: Capture<T>?) {
        if let previous = previous {
            vals.appendContentsOf(previous.vals)
        }
        self.receivers.append(o --> {
            self.vals.append($0)
        })
    }
}

class FRPJoinTests: XCTestCase {

    func testJoinHasInnerLatestValue() {
        let inner = Input<Int>(initial: 234)
        let outer = Input<Signal<Int>>(initial: inner)
        let c = Capture(outer.join(), previous: nil)
        
        XCTAssertEqual(c.vals, [234])
    }
    
    func testJoinOnInnerChange() {
        let inner = Input<Bool>(initial: false)
        let outer = Input<Signal<Bool>>(initial: inner)
        let c = Capture(outer.join(), previous: nil)
        
        inner.value = true
        inner.value = false
        XCTAssertEqual(c.vals, [false, true, false])
    }

    func testJoinOnOuterChange() {
        let outer = Input<Signal<Bool>?>(initial: nil)
        var c: Capture<Bool>? = nil
        let outerObs = outer --> {
            if let inner = $0 {
                c = Capture(inner, previous: c)
            } else {
                c = nil
            }
        }
        
        let inner = Input<Bool>(initial: false)
        outer.value = inner
        
        let inner2 = Input<Bool>(initial: true)
        outer.value = inner2
        
        XCTAssertNotNil(c)
        XCTAssertEqual(c!.vals, [false, true])
        XCTAssertNotNil(outerObs)
    }
    
    func testJoinOnBothChange() {
        let outer = Input<Signal<Bool>?>(initial: nil)
        var c: Capture<Bool>? = nil
        let outerObs = outer --> {
            if let inner = $0 {
                c = Capture(inner, previous: c)
            } else {
                c = nil
            }
        }
        
        let inner = Input<Bool>(initial: false)
        outer.value = inner
        inner.value = true
        
        XCTAssertNotNil(c)
        XCTAssertEqual(c!.vals, [false, true])
        XCTAssertNotNil(outerObs)
    }
}
