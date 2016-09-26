//
//  FRPTests.swift
//  SwiftFRP
//
//  Created by Neil Gall on 30/09/2015.
//  Copyright © 2015 Neil Gall. All rights reserved.
//

import XCTest
import SwiftCheck
@testable import SwiftFRP

// Must be a class so it can be mutated inside the observer closure
private class Capture<T> {
    var obs = [ReceiverType]()
    var vals: [T] = []
    
    init(_ o: Signal<T>) {
        self.obs.append(o --> {
            self.vals.append($0)
        })
    }
}

class FRPTests: XCTestCase {

    func testBasicProperties() {
        
        property("inputs output their values") <- forAll { (initial: Int, ns: ArrayOf<Int>) in
            let s = Input<Int>(initial: initial)
            let c = Capture(s)
    
            ns.getArray.forEach {
                s.value = $0
            }
        
            return c.vals == [initial] + ns.getArray
        }
        
        property("discarding receiver cancels output") <- forAll { (initial: Int, ns: ArrayOf<Int>) in
            let s = Input<Int>(initial: initial)
            let c = Capture(s)
    
            ns.getArray.forEach {
                s.value = $0
            }
            
            c.obs.removeAll()
            
            ns.getArray.forEach {
                s.value = $0
            }
            
            return c.vals == [initial] + ns.getArray
        }
    }
    
    func testMapProperties() {
        property("a mapped input propagates initial and changes") <- forAll { (initial: Int, ns: ArrayOf<Int>) in
            let s = Input<Int>(initial: initial)
            let m = s.map { $0 + 1 }
            let c = Capture(m)
    
            ns.getArray.forEach {
                s.value = $0
            }
            
            return c.vals == ([initial] + ns.getArray).map { $0 + 1 }
        }
        
        property("a mapped signal propagates changes") <- forAll { (ns: ArrayOf<Int>) in
            let s = Signal<Int>()
            let m = s.map { $0 * 2 }
            let c = Capture(m)
        
            ns.getArray.forEach {
                s.pushValue($0)
            }
            
            return c.vals == ns.getArray.map { $0 * 2 }
        }
    }
    
    func testFilterProperties() {
        property("a filtered input propagates changes") <- forAll { (initial: Int, ns: ArrayOf<Int>, pivot: Int) in
            let s = Input<Int>(initial: initial)
            let f = s.filter { $0 > pivot }
            let c = Capture(f)
    
            ns.getArray.forEach {
                s.value = $0
            }
            
            return c.vals == ns.getArray.filter { $0 > pivot }
        }
        
        property("a filtered signal propagates changes") <- forAll { (ns: ArrayOf<Int>, pivot: Int) in
            let s = Signal<Int>()
            let f = s.filter { $0 < pivot }
            let c = Capture(f)
            
            ns.getArray.forEach {
                s.pushValue($0)
            }
            
            return c.vals == ns.getArray.filter { $0 < pivot }
        }
    }
    
    func testUnionProperties() {
        property("union of inputs propagates only changes") <- forAll { (n0: Int, m0: Int, ns: ArrayOf<Int>, ms: ArrayOf<Int>) in
            let s1 = Input<Int>(initial: n0)
            let s2 = Input<Int>(initial: m0)
            let u = union(s1, s2)
            let c = Capture(u)
            
            let pairs = zip(ns.getArray, ms.getArray)
                
            pairs.forEach {
                s1.value = $0
                s2.value = $1
            }
            
            return c.vals == pairs.reduce([]) { $0 + [$1.0, $1.1] }
        }
        
        property("union of signals propagates changes") <- forAll { (ns: ArrayOf<Int>, ms: ArrayOf<Int>) in
            let s1 = Signal<Int>()
            let s2 = Signal<Int>()
            let u = union(s1, s2)
            let c = Capture(u)
            
            let pairs = zip(ns.getArray, ms.getArray)
                
            pairs.forEach {
                s1.pushValue($0)
                s2.pushValue($1)
            }
            
            return c.vals == pairs.reduce([]) { $0 + [$1.0, $1.1] }
        }
    }
    
    func testCombine2Properties() {
        property("combine2 propagates on every change") <- forAll { (i1: Int, i2: String, ns: ArrayOf<Int>, ms: ArrayOf<String>) in
            let s1 = Input<Int>(initial: i1)
            let s2 = Input<String>(initial: i2)
            let m = combine(s1, s2) { i,s in "\(i):\(s)" }
            let c = Capture(m)

            let pairs = zip(ns.getArray, ms.getArray)
            
            pairs.forEach {
                s1.value = $0
                s2.value = $1
            }
            
            let expect = pairs.reduce((["\(i1):\(i2)"], i2)) { (results, pair) in
                return (results.0 + ["\(pair.0):\(results.1)", "\(pair.0):\(pair.1)"], pair.1)
            }
            
            return c.vals == expect.0
        }
    }
    
    func testCombine2_dependentInputs() {
        let s = Input<Int>(initial: 0)
        let t = s.map { $0 + 5 }
        let u = s.map { $0 + 3 }
        let m = combine(t, u) { $0 * $1 }
        let c = Capture(m)
        
        s.value = 6

        XCTAssertEqual(c.vals, [15, 99])
    }

    func testCombine3_independentInputs() {
        let s1 = Input<Int>(initial: 0)
        let s2 = Input<String>(initial: "")
        let s3 = Input<Bool>(initial: false)
        let m = combine(s1, s2, s3) { i,s,b in "\(i):\(s):\(b)" }
        let c = Capture(m)

        s1.value = 123
        s2.value = "foo"
        s3.value = true
        s1.value = 234
        s2.value = "bar"
        
        XCTAssertEqual(c.vals, ["0::false", "123::false", "123:foo:false", "123:foo:true", "234:foo:true", "234:bar:true"])
    }
    
    func testCombine3_dependentInputs() {
        let s = Input<Int>(initial: 0)
        let t = s.map { $0 + 5 }
        let u = s.map { $0 * -1 }
        let m = combine(s, t, u) { $0 * $1 + $2 }
        let c = Capture(m)
        
        s.value = 7
        s.value = 9
        
        XCTAssertEqual(c.vals, [0, 77, 117])
    }
    
    func testCombine4_independentInputs() {
        let s1 = Input<Int>(initial: 0)
        let s2 = Input<Int>(initial: 0)
        let s3 = Input<Int>(initial: 0)
        let s4 = Input<Int>(initial: 0)
        let m = combine(s1, s2, s3, s4) { $0 + $1 + $2 + $3 }
        let c = Capture(m)
        
        s1.value = 1
        s2.value = 4
        s3.value = 7
        s4.value = 9

        XCTAssertEqual(c.vals, [0, 1, 5, 12, 21])
    }
    
    func testCombine5_independentInputs() {
        let s1 = Input<Int>(initial: 1)
        let s2 = Input<Int>(initial: 3)
        let s3 = Input<Int>(initial: 5)
        let s4 = Input<Int>(initial: 7)
        let s5 = Input<Int>(initial: 9)
        let m = combine(s1, s2, s3, s4, s5) { ($0 * $1) + ($2 * $3) + $4 }
        let c = Capture(m)
        
        s1.value = 2
        s2.value = 4
        s3.value = 6
        s4.value = 8
        s5.value = 10
        
        XCTAssertEqual(c.vals, [47, 50, 52, 59, 65, 66])
    }
    
    func testLatest_mapped() {
        let s = Input<Int>(initial: 0)
        let t = s.map { $0 + 1 }
        let u = t.latest()
        
        XCTAssertTrue(t.latestValue.has)
        XCTAssertEqual(u.latestValue.get, 1)

        s.value = 6
        
        XCTAssertEqual(u.latestValue.get, 7)
    }
    
    func testLatest_filtered() {
        let s = Input<Int>(initial: 0)
        let t = s.filter { $0 > 5 }
        let u = t.latest()

        XCTAssertFalse(t.latestValue.has)
        XCTAssertFalse(u.latestValue.has)
        XCTAssertNil(u.latestValue.get)
        
        s.value = 9
        
        XCTAssertFalse(t.latestValue.has)
        XCTAssertTrue(u.latestValue.has)
        XCTAssertEqual(u.latestValue.get, 9)
    }
    
    func testLatest_doesNotWrapLatest() {
        let s = Input<Int>(initial: 0)
        let l1 = s.latest()
        let l2 = l1.latest()
        XCTAssert(l1 === l2)
    }
    
    func testOnChange() {
        let s = Input<Int>(initial: 0)
        let t = Capture(s.latest())
        let u = Capture(s.onChange())

        s.value = 6
        s.value = 6
        s.value = 7

        XCTAssertEqual(t.vals, [0, 6, 6, 7])
        XCTAssertEqual(u.vals, [0, 6, 7])
    }
    
    func testGateDoesNotPushWhenGateIsFalse() {
        let s = Input<Int>(initial: 0)
        let g = Input<Bool>(initial: false)
        let t = g.gate(s)
        let c = Capture(t)
        
        s.value = 6
        XCTAssertEqual(c.vals, [])
    }

    func testGatePushesWhenGateIsTrue() {
        let s = Input<Int>(initial: 0)
        let g = Input<Bool>(initial: true)
        let t = g.gate(s)
        let c = Capture(t)
        
        s.value = 6
        XCTAssertEqual(c.vals, [6])
    }
    
    func testGatePushesDeferredOnRisingEdge() {
        let s = Input<Int>(initial: 0)
        let g = Input<Bool>(initial: false)
        let t = g.gate(s)
        let c = Capture(t)
        
        s.value = 6
        XCTAssertEqual(c.vals, [])

        g.value = true
        XCTAssertEqual(c.vals, [6])
    }
    
    func testGateDropsDeferredIfChangesAgain() {
        let s = Input<Int>(initial: 0)
        let g = Input<Bool>(initial: false)
        let t = g.gate(s)
        let c = Capture(t)

        s.value = 5
        s.value = 6
        XCTAssertEqual(c.vals, [])
        
        g.value = true
        XCTAssertEqual(c.vals, [6])
    }
    
    func testGateDefersEvents() {
        let s = Input<Int>(initial: 0)
        let g = Input<Bool>(initial: false)
        let t = g.gate(s.event())
        let c = Capture(t)
        
        s.value = 5
        s.value = 6
        XCTAssertEqual(c.vals, [])
        
        g.value = true
        XCTAssertEqual(c.vals, [6])
    }
    
    func testGateDefersEventsOnlyOnce() {
        let s = Input<Int>(initial: 0)
        let g = Input<Bool>(initial: false)
        let t = g.gate(s.event())
        let c = Capture(t)
        
        s.value = 6
        XCTAssertEqual(c.vals, [])
        
        g.value = true
        g.value = false
        g.value = true
        XCTAssertEqual(c.vals, [6])
    }
    
    func testBooleanOr() {
        let s = Input<Bool>(initial: false)
        let t = Input<Bool>(initial: false)
        let c = Capture(s || t)
        
        s.value = true
        t.value = true
        s.value = false
        t.value = false
        
        XCTAssertEqual(c.vals, [false, true, true, true, false])
    }
    
    func testBooleanAnd() {
        let s = Input<Bool>(initial: false)
        let t = Input<Bool>(initial: false)
        let c = Capture(s && t)
        
        s.value = true
        t.value = true
        s.value = false
        t.value = false
        
        XCTAssertEqual(c.vals, [false, false, true, false, false])
    }
    
    func testBooleanNot() {
        let s = Input<Bool>(initial: false)
        let c = Capture(not(s))
        
        s.value = true
        s.value = false
        
        XCTAssertEqual(c.vals, [true, false, true])
    }
    
    func testCompositionNotOr() {
        let s = Input<Bool>(initial: false)
        let t = Input<Bool>(initial: false)
        let c = Capture(not(s || t))
        
        s.value = true
        t.value = true
        s.value = false
        t.value = false
        
        XCTAssertEqual(c.vals, [true, false, false, false, true])
    }

    func testCompositionNotAnd() {
        let s = Input<Bool>(initial: false)
        let t = Input<Bool>(initial: false)
        let c = Capture(not(s && t))
        
        s.value = true
        t.value = true
        s.value = false
        t.value = false
        
        XCTAssertEqual(c.vals, [true, true, false, true, true])
    }
    
    func testEvent() {
        let s = Input<Int>(initial: 0)
        let e = s.event()
        let c = Capture(e)
        
        XCTAssertEqual(s.latestValue.get, .Some(0))
        XCTAssertNil(e.latestValue.get)
        XCTAssertEqual(c.vals, [])
        
        s.value = 5
        XCTAssertEqual(s.latestValue.get, .Some(5))
        XCTAssertNil(e.latestValue.get)
        XCTAssertEqual(c.vals, [5])
    }
}
