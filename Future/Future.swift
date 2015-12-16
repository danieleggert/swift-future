//
//  Future.swift
//  Future
//
//  Created by Daniel Eggert on 15/12/2015.
//
//  Copyright © 2015 Daniel Eggert
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// A Future is used to retrieve the result of a concurrent, asynchronous operation.
/// It is a key building block in asynchronous, non-blocking code.
///
/// **Nomenclature:** Note how the terms *Future* and *Promise* are often used interchangeably. In the  present context, the future is read-only, while the promise is what the value is set on (i.e. it's *writeable*). The future is what we'll get the evaluated value from, the promise is what the value will be set on.
///
/// In it's simplest form, we can use a Future for time consuming CPU work:
/// ````
/// let future = Future<Double>() { return estimateπ() }
/// future.whenSuccess() { print("π ≅ \($0)") }
/// ````
/// This tricial example show how a Future splits the creation of the value and processing its result into two seperate parts that are both asynchronous.
///
/// A common application of a Future is to wrap asynchronous API, such as network API. For this we use a Future-Promise pair:
/// ````
/// let (future, promise) = Future<Int>.createPromise()
/// getNumberOfNetworkHops("www.swift.org") { (hops: Int) -> () in
///   promise.completeWithValue(hops)
/// }
/// future.whenSuccess() { print("number of network hops: \($0)") }
/// ````
public final class Future<A> {
  /// Future which evalues to the result of the given closure `f` (the *promise*).
  ///
  /// Optionally passing a queue will cause `f` to get called on that queue. Otherwise the global concurrent queue with default QoS will be used.
  public init(queue: dispatch_queue_t = defaultQueue(), f: () throws -> A) {
    self.queue = queue
    execute = { [unowned self] in
      dispatch_once(&self.oncePredicate) {
        dispatch_async(self.queue, self.promise)
      }
    }
    promise = dispatch_block_create(DISPATCH_BLOCK_DETACHED) { [unowned self] in
      do {
        self.result = .Success(try f())
      } catch let e {
        self.result = .Error(e)
      }
    }
  }
  /// Create a Future and Promise pair.
  ///
  /// Completing the returned promise fulfills the returned future. This is useful for creating a `Future` that wraps API with a callback handler / completion block.
  public static func createPromise() -> (Future<A>,Promise<A>) {
    let f = Future<A>(queue: defaultQueue())
    f.execute = {}
    var result: FutureResult<A>? = nil
    f.promise = dispatch_block_create(DISPATCH_BLOCK_DETACHED) { [unowned f] in
      f.result = result
    }
    let setResult = { [weak f] (r: FutureResult<A>) -> () in
      guard let future = f else { return }
      result = r
      dispatch_once(&future.oncePredicate, future.promise)
    }
    let p = Promise<A>(setResult: setResult)
    return (f, p)
  }
  
  /// This is the queue that the future's promise will get executed on
  private let queue: dispatch_queue_t
  /// This closure will set the future's result.
  private var promise: dispatch_block_t! = nil
  /// Predicate to make sure that the promise only gets run once.
  private var oncePredicate = dispatch_once_t()
  /// The result of running the future, or `nil` if it hasn't been evaluated, yet.
  private var result: FutureResult<A>? = nil
  /// This closure will cause the future to get evaluated.
  private var execute: (() -> ())! = nil
  
  private init(queue: dispatch_queue_t) {
    self.queue = queue
  }
  /// Given a future that returns type `B` create a future that returns type `A`.
  private init<B>(queue: dispatch_queue_t, dependency: Future<B>, g: (B) throws -> A) {
    self.queue = queue
    // We store a mutable, optional value of the dependency. This allows us to release it, once we have evaluated it.
    var d = Optional.Some(dependency)
    promise = dispatch_block_create(DISPATCH_BLOCK_DETACHED) { [unowned self] in
      guard let dd = d else {  fatalError("Future dependency nil before being evaluated.") }
      guard let dependencyResult = dd.result else { fatalError("Future completed, but has no result.") }
      d = nil
      switch dependencyResult {
      case .Success(let value):
        do {
          self.result = .Success(try g(value))
        } catch let e {
          self.result = .Error(e)
        }
      case .Error(let e):
        self.result = .Error(e)
      }
    }
    execute = { [unowned self] in
      dispatch_once(&self.oncePredicate) {
        guard let dd = d else {  fatalError("Future dependency nil before being executed.") }
        dispatch_block_notify(dd.promise, self.queue, self.promise)
        dd.execute()
      }
    }
  }
}

public final class Promise<A> {
  public func completeWithValue(value: A) {
    completeWithResult(.Success(value))
  }
  public func failWithError(error: ErrorType) {
    completeWithResult(.Error(error))
  }
  private func completeWithResult(result: FutureResult<A>) {
    setResult(r: result)
  }
  private init(setResult: (r: FutureResult<A>) -> ()) {
    self.setResult = setResult
  }
  private let setResult: (r: FutureResult<A>) -> ()
}

public enum FutureResult<A> {
  case Success(A)
  case Error(ErrorType)
}

extension Future {
  /// Asynchronously access the value of the future.
  ///
  /// The passed in function `f` will get called with the successul result of the future's promise.
  /// Optionally passing a queue will cause `f` to get called on that queue. Otherwise the global concurrent queue with default QoS will be used.
  /// Note that the future will only get evaluated once. Subsequen calls will re-use the existing, evaluated value.
  public func whenSuccess(queue: dispatch_queue_t = defaultQueue(), f: (A) -> ()) {
    whenFulfilled(queue) {
      if case let .Success(value) = $0 {
        f(value)
      }
    }
  }
  /// Asynchronously access the error of the future.
  ///
  /// The passed in function `f` will get called with the error thrown by the future's promise.
  /// Optionally passing a queue will cause `f` to get called on that queue. Otherwise the global concurrent queue with default QoS will be used.
  /// Note that the future will only get evaluated once. Subsequen calls will re-use the existing, evaluated value.
  public func whenError(queue: dispatch_queue_t = defaultQueue(), f: (ErrorType) -> ()) {
    whenFulfilled(queue) {
      if case let .Error(error) = $0 {
        f(error)
      }
    }
  }
  /// Asynchronously access the result of the future.
  ///
  /// The passed in function `f` will get called when the future is fullfilled, either with the resulting value or the resulting error.
  /// Optionally passing a queue will cause `f` to get called on that queue. Otherwise the global concurrent queue with default QoS will be used.
  /// - note
  ///     The future will only get evaluated once. Subsequent calls will re-use the existing, evaluated value.
  public func whenFulfilled(queue: dispatch_queue_t = defaultQueue(), f: (FutureResult<A>) -> ()) {
    dispatch_block_notify(promise, queue) {
      guard let a = self.result else {
        fatalError("Future completed, but has no result.")
      }
      f(a)
    }
    execute()
  }
}

extension Future {
  /// Create a new future which evalues to the result of the current one applied to the given closure `g`.
  /// Optionally passing a queue will cause `g` to get called on that queue. Otherwise the global concurrent queue with default QoS will be used.
  @warn_unused_result
  public func map<T>(queue: dispatch_queue_t = defaultQueue(), g: (A) -> T) -> Future<T> {
    return Future<T>(queue: queue, dependency: self, g: g)
  }
  
  @warn_unused_result
  public func flatMap<T>(queue: dispatch_queue_t = defaultQueue(), g: (A) -> Future<T>) -> Future<T> {
    fatalError("Not implemented")
  }
  
  @warn_unused_result
  func combine<B, T>(queue: dispatch_queue_t = defaultQueue(), future: Future<B>, g: (A, B) -> T) -> Future<T> {
    fatalError("Not implemented")
  }
  
  @warn_unused_result
  public static func collection<C: CollectionType, T where C.Generator.Element == Future<T>>() -> Future<[T]> {
    fatalError("Not implemented")
  }
  
  @warn_unused_result
  public static func traverse<C: CollectionType, T>(f: (C.Generator.Element) -> T) -> Future<[T]> {
    fatalError("Not implemented")
  }
}

private func defaultQueue() -> dispatch_queue_t {
  return dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
}
