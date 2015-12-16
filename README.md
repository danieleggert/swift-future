# Swift Future

A Future is used to retrieve the result of a concurrent, asynchronous operation.
It is a key building block in asynchronous, non-blocking code.

**Nomenclature:** Note how the terms *Future* and *Promise* are often used interchangeably. In the  present context, the future is read-only, while the promise is what the value is set on (i.e. it's *writeable*). The future is what we'll get the evaluated value from, the promise is what the value will be set on.

In it's simplest form, we can use a Future for time consuming CPU work:
```swift
let future = Future<Double>() { return estimateπ() }
future.whenSuccess() { print("π ≅ \($0)") }
```
This tricial example show how a Future splits the creation of the value and processing its result into two seperate parts that are both asynchronous.

A common application of a Future is to wrap asynchronous API, such as network API. For this we use a Future-Promise pair:
```swift
let (future, promise) = Future<Int>.createPromise()
getNumberOfNetworkHops("www.swift.org") { (hops: Int) -> () in
  promise.completeWithValue(hops)
}
future.whenSuccess() { print("number of network hops: \($0)") }
```
