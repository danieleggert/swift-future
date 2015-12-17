//
//  FutureTests.swift
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

import XCTest
import Future

enum FutureTestsError : ErrorType {
  case ErrorA
}

class FutureTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func testThatFutureGetsEvaluated() {
    // Given
    let f = Future<Int>() {
      return 42
    }
    let expectation = expectationWithDescription("call result handler")
    
    // When
    f.whenFulfilled() {
      switch $0 {
      case .Success(let v):
        XCTAssertEqual(v, 42)
      case .Error(let e):
        XCTFail("\(e)")
      }
      expectation.fulfill()
    }
    
    // Then
    waitForExpectationsWithTimeout(0.1, handler: nil)
  }
  
  func testThatFutureGetsEvaluatedOnlyOnce() {
    // Given
    var c = Int32()
    let f = Future<Int>() {
      OSAtomicIncrement32(&c)
      return 42
    }
    let expectations = (0..<10).map {
      expectationWithDescription("call result handler \($0)")
    }
    
    // When
    expectations.forEach { expectation in
      f.whenFulfilled() {
        switch $0 {
        case .Success(let v):
          XCTAssertEqual(v, 42)
        case .Error(let e):
          XCTFail("\(e)")
        }
        expectation.fulfill()
      }
    }
    
    // Then
    waitForExpectationsWithTimeout(0.1, handler: nil)
    XCTAssertEqual(c, 1)
  }
}

// MARK: Future-Promise Pair
extension FutureTests {
  func testThatCompletingThePromiseFulfillsTheFuture() {
    // Given
    let (future, promise) = Future<Int>.createPromise()
    let expectation = expectationWithDescription("fulfilled")
    future.whenFulfilled() {
      switch $0 {
      case .Success(let v):
        XCTAssertEqual(v, 42)
      case .Error(let e):
        XCTFail("\(e)")
      }
      expectation.fulfill()
    }
    
    // When
    promise.completeWithValue(42)
    
    // Then
    waitForExpectationsWithTimeout(0.1, handler: nil)
  }
}

// MARK: map
extension FutureTests {
  func testThatItCanMapAFutureWithAClosure() {
    // Given
    let f1 = Future<Int>() {
      return 42
    }
    let f2 = f1.map { "\($0)" }
    let expectation = expectationWithDescription("call result handler")
    
    // When
    f2.whenFulfilled() {
      switch $0 {
      case .Success(let v):
        XCTAssertEqual(v, "42")
      case .Error(let e):
        XCTFail("\(e)")
      }
      expectation.fulfill()
    }
    
    // Then
    waitForExpectationsWithTimeout(0.1, handler: nil)
  }
  
  func testThatItCanMapAFuturePromisePair() {
    // Given
    let (f1, promise) = Future<Int>.createPromise()
    let f2 = f1.map { "\($0)" }
    let expectation = expectationWithDescription("call result handler")
    
    f2.whenFulfilled() {
      switch $0 {
      case .Success(let v):
        XCTAssertEqual(v, "42")
      case .Error(let e):
        XCTFail("\(e)")
      }
      expectation.fulfill()
    }
    
    // When
    promise.completeWithValue(42)
    
    // Then
    waitForExpectationsWithTimeout(0.1, handler: nil)
  }
  
  func testThatItCanMappingRetainsTheOriginalFuture() {
    // Given
    var mutableValue = Int(0)
    var f2: Future<String>? = nil
    do {
      let f1 = Future<Int>() {
        return mutableValue
      }
      f2 = f1.map { "\($0)" }
    }
    let expectation = expectationWithDescription("call result handler")
    
    // When
    mutableValue = 42
    f2?.whenFulfilled() {
      switch $0 {
      case .Success(let v):
        XCTAssertEqual(v, "42")
      case .Error(let e):
        XCTFail("\(e)")
      }
      expectation.fulfill()
    }
    
    // Then
    waitForExpectationsWithTimeout(0.1, handler: nil)
  }
  
  func testThatAMappedFutureGetsEvaluatedOnlyOnce() {
    // Given
    var c = Int32()
    var f: Future<String>? = nil
    do {
      let f1 = Future<Int>() {
        OSAtomicIncrement32(&c)
        return 42
      }
      f = f1.map { "\($0)" }
    }
    let expectations = (0..<10).map {
      expectationWithDescription("call result handler \($0)")
    }
    
    // When
    expectations.forEach { expectation in
      f?.whenFulfilled() {
        switch $0 {
        case .Success(let v):
          XCTAssertEqual(v, "42")
        case .Error(let e):
          XCTFail("\(e)")
        }
        expectation.fulfill()
      }
    }
    
    // Then
    waitForExpectationsWithTimeout(0.1, handler: nil)
    XCTAssertEqual(c, 1)
  }
}

private final class DummyObject {
  func doSomething() -> Int { return 42 }
}

// MARK: MemoryManagement
extension FutureTests {
  func testThatTheFutureGetsReleasedWhenFulfilled() {
    // Given
    weak var weakF: Future<Int>? = nil
    
    // When
    do {
      let f = Future<Int>() { 42 }
      weakF = f
      let expectation = expectationWithDescription("fulfilled")
      XCTAssert(weakF != nil)
      f.whenFulfilled() {_ in expectation.fulfill() }
      waitForExpectationsWithTimeout(0.1, handler: nil)
    }
    
    // Then
    XCTAssert(weakF == nil)
  }
  
  func testThatThePromiseClosureGetsReleasedWhenFulfilled() {
    // Given
    weak var weakDummy: DummyObject? = nil
    
    // When
    do {
      let f = { () -> Future<Int> in
        let d = DummyObject()
        weakDummy = d
        let f = Future<Int>() { return d.doSomething() }
        return f
      }()
      XCTAssert(weakDummy != nil)
      let expectation = expectationWithDescription("fulfilled")
      f.whenFulfilled() {_ in expectation.fulfill() }
      waitForExpectationsWithTimeout(0.1, handler: nil)
    }
    
    // Then
    XCTAssert(weakDummy == nil)
  }
  func testThatItReleasesTheFutureOfAPromiseFuturePairWhenFulfilled() {
    // Given
    weak var weakF: Future<Int>? = nil
    
    // When
    do {
      let (f, promise) = Future<Int>.createPromise()
      weakF = f
      let expectation = expectationWithDescription("fulfilled")
      f.whenFulfilled() { _ in expectation.fulfill() }
      promise.completeWithValue(42)
      waitForExpectationsWithTimeout(0.1, handler: nil)
    }
    
    // Then
    XCTAssert(weakF == nil)
  }
  
  func testThatMappedFuturesGetsReleasedWhenFulfilled() {
    // Given
    weak var weakF1: Future<Int>? = nil
    weak var weakF2: Future<String>? = nil
    
    // When
    do {
      let f1 = Future<Int>() { 42 }
      weakF1 = f1
      let f2 = f1.map { "\($0)" }
      weakF2 = f2
      let expectation = expectationWithDescription("call result handler")
      f2.whenFulfilled() { _ in expectation.fulfill() }
      waitForExpectationsWithTimeout(0.1, handler: nil)
    }
    // Then
    XCTAssert(weakF1 == nil)
    XCTAssert(weakF2 == nil)
  }
  func testThatThePromiseClosuresOfMappedFuturesGetReleasedWhenFulfilled() {
    // Given
    weak var weakDummy1: DummyObject? = nil
    weak var weakDummy2: DummyObject? = nil
    
    // When
    do {
      let d1 = DummyObject()
      weakDummy1 = d1
      let f1 = Future<Int>() { return d1.doSomething() }
      let d2 = DummyObject()
      weakDummy2 = d2
      let f2 = f1.map { $0 + d2.doSomething() }
      let expectation = expectationWithDescription("call result handler")
      XCTAssert(weakDummy1 != nil)
      XCTAssert(weakDummy2 != nil)
      f2.whenFulfilled() { _ in expectation.fulfill() }
      waitForExpectationsWithTimeout(0.1, handler: nil)
    }
    // Then
    XCTAssert(weakDummy1 == nil)
    XCTAssert(weakDummy2 == nil)
  }
}
