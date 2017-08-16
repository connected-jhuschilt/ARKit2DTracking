//
//  Rectangle.swift
//  ARKit2DTracking
//
//  Created by cl-dev7 on 2017-08-15.
//  Copyright © 2017 Vectorform. All rights reserved.
//

import UIKit
import Vision

class Rectangle: NSObject {

    let trackRequest: VNTrackRectangleRequest
    var observation: VNRectangleObservation

    init(initialObservation: VNRectangleObservation, trackRequest: VNTrackRectangleRequest) {
        self.observation = initialObservation
        self.trackRequest = trackRequest
    }
}

extension VNRectangleObservation {
    var center: CGPoint {
        var rect = self.boundingBox
        
        // Flip coordinates
        rect = rect.applying(CGAffineTransform(scaleX: 1, y: -1))
        rect = rect.applying(CGAffineTransform(translationX: 0, y: 1))
        
        return CGPoint(x: rect.midX, y: rect.midY)
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let xDistance = point.x - self.x
        let yDistance = point.y - self.y
        
        return sqrt((xDistance * xDistance) + (yDistance * yDistance))
    }
}
