//
//  Combine.swift
//  ScotTraffic
//
//  Created by Neil Gall on 04/01/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation

// Combiners take multiple signals and a reducing function to form a new signal
// with the result of the reduction. If multiple sources change in the same
// transaction the combiner only propagates a single change, at the end of the
// transaction.

class Combiner<Value>: Signal<Value> {
    private var transactionCount: Int = 0
    private var needsUpdate: Bool = false
    var receivers: [ReceiverType] = []

    func update<S>(transaction: Transaction<S>) {
        switch transaction {
        case .Begin:
            if transactionCount == 0 {
                self.pushTransaction(.Begin)
                needsUpdate = false
            }
            transactionCount += 1
            
        case .End:
            needsUpdate = true
            fallthrough
            
        case .Cancel:
            assert(transactionCount > 0)
            transactionCount -= 1
            if transactionCount == 0 {
                if needsUpdate, let value = latestValue.get {
                    pushTransaction(.End(value))
                    needsUpdate = false
                } else {
                    pushTransaction(.Cancel)
                }
            }
        }
    }
}

class Combine2<Source1: SignalType, Source2: SignalType, CombinedType> : Combiner<CombinedType> {
    typealias CombineFunction = (Source1.ValueType, Source2.ValueType) -> CombinedType
    
    let combine: CombineFunction
    let latest1: Signal<Source1.ValueType>
    let latest2: Signal<Source2.ValueType>
    
    init(_ s1: Source1, _ s2: Source2, combine: CombineFunction) {
        self.combine = combine
        latest1 = s1.latest()
        latest2 = s2.latest()
        super.init()
        receivers.append(Receiver(latest1) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest2) { [weak self] t in self?.update(t) })
    }
    
    override var latestValue: LatestValue<CombinedType> {
        guard let t1 = latest1.latestValue.get, t2 = latest2.latestValue.get else {
            return .None
        }
        return .Computed({ self.combine(t1, t2) })
    }
}

class Combine3<Source1: SignalType, Source2: SignalType, Source3: SignalType, CombinedType> : Combiner<CombinedType> {
    typealias CombineFunction = (Source1.ValueType, Source2.ValueType, Source3.ValueType) -> CombinedType

    let combine: CombineFunction
    let latest1: Signal<Source1.ValueType>
    let latest2: Signal<Source2.ValueType>
    let latest3: Signal<Source3.ValueType>
    
    init(_ s1: Source1, _ s2: Source2, _ s3: Source3, combine: CombineFunction) {
        self.combine = combine
        latest1 = s1.latest()
        latest2 = s2.latest()
        latest3 = s3.latest()
        super.init()
        receivers.append(Receiver(latest1) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest2) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest3) { [weak self] t in self?.update(t) })
    }
    
    override var latestValue: LatestValue<CombinedType> {
        guard let t1 = latest1.latestValue.get, t2 = latest2.latestValue.get, t3 = latest3.latestValue.get else {
            return .None
        }
        return .Computed({ self.combine(t1, t2, t3) })
    }
}

class Combine4<Source1: SignalType, Source2: SignalType, Source3: SignalType, Source4: SignalType, CombinedType> : Combiner<CombinedType> {
    typealias CombineFunction = (Source1.ValueType, Source2.ValueType, Source3.ValueType, Source4.ValueType) -> CombinedType

    let combine: CombineFunction
    let latest1: Signal<Source1.ValueType>
    let latest2: Signal<Source2.ValueType>
    let latest3: Signal<Source3.ValueType>
    let latest4: Signal<Source4.ValueType>
    
    init(_ s1: Source1, _ s2: Source2, _ s3: Source3, _ s4: Source4, combine: CombineFunction) {
        self.combine = combine
        latest1 = s1.latest()
        latest2 = s2.latest()
        latest3 = s3.latest()
        latest4 = s4.latest()
        super.init()
        receivers.append(Receiver(latest1) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest2) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest3) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest4) { [weak self] t in self?.update(t) })
    }
    
    override var latestValue: LatestValue<CombinedType> {
        guard let t1 = latest1.latestValue.get, t2 = latest2.latestValue.get, t3 = latest3.latestValue.get, t4 = latest4.latestValue.get else {
            return .None
        }
        return .Computed({ self.combine(t1, t2, t3, t4) })
    }
}

class Combine5<Source1: SignalType, Source2: SignalType, Source3: SignalType, Source4: SignalType, Source5: SignalType, CombinedType> : Combiner<CombinedType> {
    typealias CombineFunction = (Source1.ValueType, Source2.ValueType, Source3.ValueType, Source4.ValueType, Source5.ValueType) -> CombinedType

    let combine: CombineFunction
    let latest1: Signal<Source1.ValueType>
    let latest2: Signal<Source2.ValueType>
    let latest3: Signal<Source3.ValueType>
    let latest4: Signal<Source4.ValueType>
    let latest5: Signal<Source5.ValueType>
    
    init(_ s1: Source1, _ s2: Source2, _ s3: Source3, _ s4: Source4, _ s5: Source5, combine: CombineFunction) {
        self.combine = combine
        latest1 = s1.latest()
        latest2 = s2.latest()
        latest3 = s3.latest()
        latest4 = s4.latest()
        latest5 = s5.latest()
        super.init()
        receivers.append(Receiver(latest1) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest2) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest3) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest4) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest5) { [weak self] t in self?.update(t) })
    }
    
    override var latestValue: LatestValue<CombinedType> {
        guard let t1 = latest1.latestValue.get, t2 = latest2.latestValue.get, t3 = latest3.latestValue.get, t4 = latest4.latestValue.get, t5 = latest5.latestValue.get else {
            return .None
        }
        return .Computed({ self.combine(t1, t2, t3, t4, t5) })
    }
}

class Combine6<Source1: SignalType, Source2: SignalType, Source3: SignalType, Source4: SignalType, Source5: SignalType, Source6: SignalType, CombinedType> : Combiner<CombinedType> {
    typealias CombineFunction = (Source1.ValueType, Source2.ValueType, Source3.ValueType, Source4.ValueType, Source5.ValueType, Source6.ValueType) -> CombinedType
    let combine: CombineFunction
    let latest1: Signal<Source1.ValueType>
    let latest2: Signal<Source2.ValueType>
    let latest3: Signal<Source3.ValueType>
    let latest4: Signal<Source4.ValueType>
    let latest5: Signal<Source5.ValueType>
    let latest6: Signal<Source6.ValueType>
    
    init(_ s1: Source1, _ s2: Source2, _ s3: Source3, _ s4: Source4, _ s5: Source5, _ s6: Source6, combine: CombineFunction) {
        self.combine = combine
        latest1 = s1.latest()
        latest2 = s2.latest()
        latest3 = s3.latest()
        latest4 = s4.latest()
        latest5 = s5.latest()
        latest6 = s6.latest()
        super.init()
        receivers.append(Receiver(latest1) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest2) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest3) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest4) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest5) { [weak self] t in self?.update(t) })
        receivers.append(Receiver(latest6) { [weak self] t in self?.update(t) })
    }
    
    override var latestValue: LatestValue<CombinedType> {
        guard let t1 = latest1.latestValue.get, t2 = latest2.latestValue.get, t3 = latest3.latestValue.get, t4 = latest4.latestValue.get, t5 = latest5.latestValue.get, t6 = latest6.latestValue.get else {
            return .None
        }
        return .Computed({ self.combine(t1, t2, t3, t4, t5, t6) })
    }
}

public func combine<Source1: SignalType, Source2: SignalType, CombinedType>
    (s1: Source1, _ s2: Source2,
    combine: (Source1.ValueType, Source2.ValueType) -> CombinedType) -> Signal<CombinedType> {
        return Combine2(s1, s2, combine: combine)
}

public func combine<Source1: SignalType, Source2: SignalType, Source3: SignalType, CombinedType>
    (s1: Source1, _ s2: Source2, _ s3: Source3,
    combine: (Source1.ValueType, Source2.ValueType, Source3.ValueType) -> CombinedType) -> Signal<CombinedType> {
        return Combine3(s1, s2, s3, combine: combine)
}

public func combine<Source1: SignalType, Source2: SignalType, Source3: SignalType, Source4: SignalType, CombinedType>
    (s1: Source1, _ s2: Source2, _ s3: Source3, _ s4: Source4,
    combine: (Source1.ValueType, Source2.ValueType, Source3.ValueType, Source4.ValueType) -> CombinedType) -> Signal<CombinedType> {
        return Combine4(s1, s2, s3, s4, combine: combine)
}

public func combine<Source1: SignalType, Source2: SignalType, Source3: SignalType, Source4: SignalType, Source5: SignalType, CombinedType>
    (s1: Source1, _ s2: Source2, _ s3: Source3, _ s4: Source4, _ s5: Source5,
    combine: (Source1.ValueType, Source2.ValueType, Source3.ValueType, Source4.ValueType, Source5.ValueType) -> CombinedType) -> Signal<CombinedType> {
        return Combine5(s1, s2, s3, s4, s5, combine: combine)
}

public func combine<Source1: SignalType, Source2: SignalType, Source3: SignalType, Source4: SignalType, Source5: SignalType, Source6: SignalType, CombinedType>
    (s1: Source1, _ s2: Source2, _ s3: Source3, _ s4: Source4, _ s5: Source5, _ s6: Source6,
    combine: (Source1.ValueType, Source2.ValueType, Source3.ValueType, Source4.ValueType, Source5.ValueType, Source6.ValueType) -> CombinedType) -> Signal<CombinedType> {
        return Combine6(s1, s2, s3, s4, s5, s6, combine: combine)
}
