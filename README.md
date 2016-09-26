# SwiftFRP
This repository contains the Functional Reactive Programming framework used in [ScotTraffic 2](https://itunes.apple.com/gb/app/scottraffic-2/id1058109148?mt=8). Like most of my code this was created for pedagogical reasons more than anything else. I'd have been much quicker just importing RxSwift and getting on with the app, but learning to use a library is nothing like learning how it works inside. SwiftFRP is loosely based on the functional reactive programming ideas described in the papers of [Conal Elliott](http://conal.net). I was particularly influenced by [Push-Pull FRP](http://conal.net/papers/push-pull-frp/push-pull-frp.pdf), however the central idea of _Behaviours_ is somewhat lost in my library, which focuses more on values which change only in response to external events. At some point I'd like to revisit the whole thing with the original FRP concepts in mind.

## Signal

If you're reading the code to understand it, start at `Types.swift`. The workhorse of the library is `Signal`, which represents a value that can change in response to some event. The word *value* will come up a lot here - a key concept is that the data passed around and flowing through the framework consists of immutable value types. A `Signal` has a list of observers, which can be modified with `addObserver()` and `removeObserver()`, and a function `pushValue()` which delivers a new value to every observer. Add an observer by passing a function of type `Transaction<Value> -> Void`, and remove it later using the opaque `Observer` handle which is returned.

`Signal` exposes the idea of a `Transaction` but client code does not normally need to deal in transactions. However if you implement new signals by conforming to the `SignalType` protocol, you have to deal with transactions directly. More on transactions later.

Finally `Signal` has a `latestValue` property, of type `LatestValue<Value>`, which represents or holds the last value sent by this signal to its observers. Depending on the signal type, there may be no latest value (`case .None`), a cached latest value (`case .Stored`) or a value which is computed on access (`case .Computed`). `latestValue` is often useful at the imperative edges, when dealing with callback APIs which must access the same data multiple times, such as `UITableViewDataSource`.

A special type of `Signal` is an `Input`, which can be assigned a value directly. `Input`s live at the input side of an imperative shell, and are one way new data enters the FRP system.

## Receiver

A `Receiver` is an object wrapper around `Signal.addObserver()` and `Signal.removeObserver()`. Construct with a signal and a `Transaction<Value> -> Void` function, and it remains attached to the signal as long as the object lives. A common pattern is to create an array of `ReceiverType`s and add each created receiver to manage their lifetimes.

Above I said you won't deal in `Transaction`s much, so there's a specialised `Receiver` called `Output`. This takes a simpler `ValueType -> Void` function, and delivers a new value to that function whenever a transaction completes.

## Functional Core, Imperative shell

The framework is intended to be used where the core logic is implemented with a _functional core_, surrounded by an _imperative shell_ which acts as an interface to the things that must actually happen in your application. Button taps, network responses, timers, `NSNotification` events, etc. inject data via `Input`s, and `Output`s yield transformed values to update the UI, generate further network requests, write files to disk, update user preferences, etc.

This idea is so cental, the framework defines a special symmetrical syntax for it. Although you can send a value into an `Input` with `pushValue()`, it is more idiomatic to use the `<--` operator:

```swift
    let x = Input<Int>(initial: 0)
    ...
    x <--- 3
```

Likewise, an `Output` can be created on a `Signal using `-->`:

```swift
    let y = Signal<Int>
    ...
    let receiver = y --> { (value: Int) in
        print("\(value)")
    }
```

## Transformations

The above sounds like elaborate plumbing and not much more. The real power in the functional core arrives in the form of _signal combinators_, many of which look like traditional functional programming primitives such as `map`, `filter` and `reduce`. Each is implementred as a `Signal` subclass, but a extension on `SignalType` provides a more convenient API:

```swift
    let x = Input<Int>(initial: 0)
    let y = x.map { x in x * 3 }
    let receiver = y --> { print($0) }
    x <-- 3
    x <-- 4
    x <-- 5
```

The above prints 9, 12 and 15. 

```swift
    let x = Input<Int>(initial: 0)
    let y = filter { x in x < 5 }
    let receiver = y --> { print($0) }
    x <-- 3
    x <-- 4
    x <-- 7
```

This prints 3 and 4.

Both `y`s above are also `Signal`s, so further operations could be applied to these objects. Note that the result of `map` will provide a computed `latestValue`, invoking the transformation function each time it is accessed. If this is expensive, wrap a mapped signal in a call to `latest()` to turn it into a `Signal` which caches a copy of every value that propagates through it.

`union` takes a number of signals of the same type and yields a single signal which outputs the value from any of the source signals. `onChange` yields a signal which only propagates changes in the signal value. `notNil` turns a signal of optional type into a non-optional type by filtering out any `nil` value.

## Combiners

Sometimes a calculation requires more than one input, and this is where _Combiners_ come in. `combine` takes a number of `Signal` parameters and a combining function which receives a value from each signal as a parameter. Overloads of `combine` are provided up to six parameters. The following creates a signal which is always the addition of `x` and `y`:

```swift
    let x = Input<Int>(initial: 0)
    let y = Input<Int>(initial: 0)
    let z = combine(x, y) { $0 + $1 }
```

In the above case, x and y are separate inputs so each change to either of them will result in a new output form the combined signal. What if `x` and `y` have some dependency relationship however?

```swift
    let w = Input<Int>(initial: 0)
    let x = w.map { $0 + 2 }
    let y = w.map { $0 - 9 }.filter { $0 < 5 }
    let z = combine(x, y) { $0 + $1 }
```

On a change to `w`, we want all the dependent signals to change just once, and combiners provide exactly this property. `z` will either output a single value in response to an input on `w`, or nothing at all if the filter on `y` is not satisfied.

## Booleans

There are some combinators which only apply for some data types in filters. Booleans in particular can be combined in special ways. `&&`, `||` and `not` do what you'd expect:

```swift
    let x = Signal<Bool>
    let y = Signal<Bool>
    let x_and_y = x && y
    let neither_x_nor_y = not(x || y)
```

`onRisingEdge` and `onFallingEdge` implement a simple boolean edge detection, invoking a parameterless function in each case.

```swift
    let x = Signal<Bool>
    let receiver = x.onRisingEdge { print("x went from false to true") }
```

## Gates

A final type of combinator is a gate, which prevents propagation of some other signal while a boolean signal remains false. For example:

```swift
    let uiStuff = Signal<UIStuff>
    let animating = Signal<Bool>
    let receiver = animating.gate(uiStuff) { updateUI($0) }
```

Bracket animations with `animating <-- true` and `animating <-- false`, and regardless of when `uiStuff` is updated, the call to `updateUI()` happens with the latest values only after the animation has finished.

## Transactions

`Transactions` are the lowest-level interaction between `Signal`s. Every change is performed with a breadth-first propagation of two stages through the dependency graph. The first stage simply marks that a transaction is beginning. The second stage is either a transaction end, or a cancellation. Simple combinators like `map` pass both transaction stages through unchanged, only transforming the value inside. Combinators such as `filter` or `gate` will cancel transactions which they do not allow to propagate. This is the means by which Combiners only propagate a single value in response to changes in multiple sources.
