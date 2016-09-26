//
//  Throttle.swift
//  ScotTraffic
//
//  Created by Neil Gall on 04/01/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation


class Throttle<ValueType> : Signal<ValueType> {
    private let timer: dispatch_source_t
    private let minimumInterval: NSTimeInterval
    private var lastPushTimestamp: CFAbsoluteTime = 0
    private var receiver: ReceiverType!
    private var transactionCount: Int = 0
    private var timerActive: Bool = false
    
    init(_ source: Signal<ValueType>, minimumInterval: NSTimeInterval, queue: dispatch_queue_t) {
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
        self.minimumInterval = minimumInterval
        
        super.init()
        
        self.receiver = Receiver(source) { [weak self] transaction in
            self?.transact(transaction)
        }
    }
    
    private func transact(transaction: Transaction<ValueType>) {
        switch transaction {
        case .Begin:
            if transactionCount == 0 {
                pushTransaction(transaction)
            }
            transactionCount += 1
            
        case .End:
            dispatch_suspend(self.timer)
            if timerActive {
                endTransaction(.Cancel)
                timerActive = false
            }
            
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastPushTimestamp > minimumInterval {
                endTransaction(transaction)
                lastPushTimestamp = now
                
            } else {
                deferEndTransaction(transaction)
            }
            
        case .Cancel:
            endTransaction(transaction)
        }
    }
    
    deinit {
        dispatch_source_cancel(timer)
    }
    
    private func endTransaction(transaction: Transaction<ValueType>) {
        transactionCount -= 1
        if transactionCount == 0 {
            pushTransaction(transaction)
        }
    }
    
    private func deferEndTransaction(transaction: Transaction<ValueType>) {
        dispatch_source_set_event_handler(timer) { [weak self] in
            self?.endTransaction(transaction)
            self?.lastPushTimestamp = CFAbsoluteTimeGetCurrent()
            self?.timerActive = false
        }
        
        dispatch_source_set_timer(timer,
            DISPATCH_TIME_NOW,
            nanosecondsFromSeconds(minimumInterval),
            nanosecondsFromSeconds(minimumInterval * 0.2))
        
        timerActive = true
        dispatch_resume(timer)
    }
}


extension Signal {
    public func throttle(minimumInterval: NSTimeInterval, queue: dispatch_queue_t) -> Signal<ValueType> {
        return Throttle(self, minimumInterval: minimumInterval, queue: queue)
    }
}

private func nanosecondsFromSeconds(seconds: NSTimeInterval) -> UInt64 {
    let nanoseconds = seconds * Double(NSEC_PER_SEC)
    return UInt64(nanoseconds)
}
