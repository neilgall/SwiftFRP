//
//  Throttle.swift
//  SwiftFRP
//
//  Created by Neil Gall on 04/01/2016.
//  Copyright © 2016 Neil Gall. All rights reserved.
//

import Foundation


class Throttle<ValueType> : Signal<ValueType> {
    private let timer: DispatchSourceTimer
    private let minimumInterval: TimeInterval
    private var lastPushTimestamp: CFAbsoluteTime = 0
    private var receiver: ReceiverType!
    private var transactionCount: Int = 0
    private var timerActive: Bool = false
    
    init(_ source: Signal<ValueType>, minimumInterval: TimeInterval, queue: DispatchQueue) {
        self.timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: queue)
        self.minimumInterval = minimumInterval
        
        super.init()
        
        self.receiver = Receiver(source) { [weak self] transaction in
            self?.transact(transaction)
        }
    }
    
    private func transact(_ transaction: Transaction<ValueType>) {
        switch transaction {
        case .begin:
            if transactionCount == 0 {
                pushTransaction(transaction)
            }
            transactionCount += 1
            
        case .end:
            self.timer.suspend()
            if timerActive {
                endTransaction(.cancel)
                timerActive = false
            }
            
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastPushTimestamp > minimumInterval {
                endTransaction(transaction)
                lastPushTimestamp = now
                
            } else {
                deferEndTransaction(transaction)
            }
            
        case .cancel:
            endTransaction(transaction)
        }
    }
    
    deinit {
        timer.cancel()
    }
    
    private func endTransaction(_ transaction: Transaction<ValueType>) {
        transactionCount -= 1
        if transactionCount == 0 {
            pushTransaction(transaction)
        }
    }
    
    private func deferEndTransaction(_ transaction: Transaction<ValueType>) {
        timer.setEventHandler { [weak self] in
            self?.endTransaction(transaction)
            self?.lastPushTimestamp = CFAbsoluteTimeGetCurrent()
            self?.timerActive = false
        }
        
        timer.scheduleOneshot(deadline: DispatchTime.now() + minimumInterval)
        
        timerActive = true
        timer.resume()
    }
}


extension Signal {
    public func throttle(_ minimumInterval: TimeInterval, queue: DispatchQueue) -> Signal<ValueType> {
        return Throttle(self, minimumInterval: minimumInterval, queue: queue)
    }
}
