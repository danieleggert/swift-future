//
//  ExecutionContext.swift
//  Future
//
//  Created by Daniel Eggert on 16/12/2015.
//  Copyright © 2015 Nulaq. All rights reserved.
//

import Foundation


/// Defines a queue to run blocks on, and a QoS (quality of service) to run blocks with.
///
/// The default is to pick a queue with a specific QoS, and let the block inherit that QoS (by means of `QOS_CLASS_UNSPECIFIED`).
public struct ExecutionContext {
  public let queue: dispatch_queue_t
  public let qualityOfService: dispatch_qos_class_t
}

extension ExecutionContext {
  public static var DefaultContext: ExecutionContext = {
    ExecutionContext(
      queue: dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0),
      qualityOfService: QOS_CLASS_UNSPECIFIED)
  }()
}

internal extension ExecutionContext {
  func createBlock(b: dispatch_block_t) -> dispatch_block_t {
    switch qualityOfService {
    case QOS_CLASS_UNSPECIFIED:
      return dispatch_block_create(DISPATCH_BLOCK_NO_QOS_CLASS, b)
    default:
      return dispatch_block_create_with_qos_class(DISPATCH_BLOCK_ENFORCE_QOS_CLASS, qualityOfService, 0, b)
    }
  }
}
