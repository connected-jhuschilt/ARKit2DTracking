//
//  ViewController.swift
//  CocoaHeadDemo
//
//  Created by Jeff Meador on 6/26/17.
//  Copyright © 2017 Vectorform. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    // MARK: - Properties
    
    @IBOutlet var sceneView: ARSCNView!
    
    var detectedDataAnchor: ARAnchor?
    var processing = false
    
    // MARK: - View Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureAndRunARSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseARSession()
    }
    
    
    // MARK: - Additional Setup
    
    func setupSceneView() {
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
    }
    
    func configureAndRunARSession() {
        // test if device is capable of running AR
        if ARWorldTrackingConfiguration.isSupported {
            let configuration = ARWorldTrackingConfiguration()
            
            configuration.planeDetection = .horizontal
            configuration.worldAlignment = .gravity
            
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        } else {
            let alertVC = UIAlertController(title: "AR Not Supported", message: "This requires an iPhone 6s or newer, or an iPad Pro.", preferredStyle: .alert)
            alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            
            present(alertVC, animated: true, completion: nil)
        }
    }
    
    func pauseARSession() {
        sceneView.session.pause()
    }
    
    
    // MARK: - Vision
    
    func resctangleDetector(frame: ARFrame) {
        print("Anchor coun for Frame: \(frame.anchors.count)")
        
        for anchor in frame.anchors {
            print("\t\t\(anchor)")
        }
        
        
        // Only run one Vision request at a time
        if !self.processing {
            
            self.processing = true
            
            // Create a Rectangle Detection Request
            let request = VNDetectRectanglesRequest { (request, error) in
                guard let observations = request.results as? [VNRectangleObservation] else {
                    print("Unexpected Observation type")
                    return
                }
                
                if let rectangle = observations.first {
                    var rect = rectangle.boundingBox
                    
                    // Flip coordinates
                    rect = rect.applying(CGAffineTransform(scaleX: 1, y: -1))
                    rect = rect.applying(CGAffineTransform(translationX: 0, y: 1))
                    
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    
                    DispatchQueue.main.async {
                        // Perform a hit test on the ARFrame to find a surface
                        // TODO: More experiment needed with the HitTest.Result options
                        
                        // ARHitTestResult.ResultType rawValues: featurePoint: 1, estimatedHorizontalPlane: 2, existingPlane: 8, existingPlaneUsingExtent: 16
                        
                        let hitTestResults = frame.hitTest(center, types: [.existingPlane, .existingPlaneUsingExtent, .estimatedHorizontalPlane])
                        
//                            print("  hitTestResults.count: \(hitTestResults.count) \(String(describing: (hitTestResults.first?.anchor as? ARPlaneAnchor)?.extent))")
                        
                            for hit in hitTestResults {
//                                print("\t\t\(hit.type)")
//                                print("\t\t\t\(hit.distance)")
                                print("\t\t\t\t\(String(describing: hit.anchor))")
                            }
                        
                        // Cards are 0.091m x 0.079m, so we'll accept extents between 6cm - 11cm
                        if let hitTestResult = hitTestResults.first(where: { hitTest in
                            if let planeAnchor = hitTest.anchor as? ARPlaneAnchor,
//                                planeAnchor.extent.x > 0.06 && planeAnchor.extent.x < 0.11,
//                                planeAnchor.extent.z > 0.06 && planeAnchor.extent.z < 0.11
                                planeAnchor.extent.x > 0.2 && planeAnchor.extent.x < 0.5,
                                planeAnchor.extent.z > 0.2 && planeAnchor.extent.z < 0.5
                            {
                                return true
                            }
                            return false
                        })
                        {
                            
                            // If we already have an anchor, update the position of the attached node
                            if let detectedDataAnchor = self.detectedDataAnchor,
                                let node = self.sceneView.node(for: detectedDataAnchor) {
                                
                                node.transform = SCNMatrix4(hitTestResult.worldTransform)
                            } else {
                                // Create an anchor. The node will be created in delegate methods
                                self.detectedDataAnchor = ARAnchor(transform: hitTestResult.worldTransform)
                                self.sceneView.session.add(anchor: self.detectedDataAnchor!)
                            }
                        }
                        
                        self.processing = false
                    }
                } else {
                    self.processing = false
                }
            }
            request.maximumObservations = 1 // only want 1 card
            // TODO: Vision minimumSize has no relative physical size, can try to use ARKit physical size
            request.minimumSize = 0.2 // Minimum size is percent of image size
            
            
            // Process the request in the background
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Create a request handler using the captured image from the ARFrame
                    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                                                    options: [:])
                    // Process the request
                    try imageRequestHandler.perform([request])
                } catch {
                    print("Error")
                }
            }
        }
    }
    
//    func createRectangleTrackingRequest(for rectangleObservationList: [VNRectangleObservation]) {
//        for rectangle in rectangleObservationList {
//            let trackingRequest = VNTrackRectangleRequest(rectangleObservation: rectangle, completionHandler: self.updateAnchor)
//        }
//    }
//
//    func updateAnchor(request: VNRequest, error: Error?) {
//        if error != nil {
//
//        } else {
//            print("Rectangle Tracking lost.")
//        }
//    }
    
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // TODO: Notify the user through an indicator if the tracking state is limited
        print("cameraDidChangeTrackingState: \(camera.trackingState)")
    }
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        resctangleDetector(frame: frame)
    }
    
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        
        // If this is our anchor, create a node
        if self.detectedDataAnchor?.identifier == anchor.identifier {
            
            // Create a 3D Cup to display
            guard let virtualObjectScene = SCNScene(named: "cup.scn", inDirectory: "Models.scnassets/cup") else {
                return nil
            }
            
            let wrapperNode = SCNNode()
            
            for child in virtualObjectScene.rootNode.childNodes {
                child.geometry?.firstMaterial?.lightingModel = .physicallyBased
                child.movabilityHint = .movable
                wrapperNode.addChildNode(child)
            }
            
            // Set its position based off the anchor
            wrapperNode.transform = SCNMatrix4(anchor.transform)
            
            return wrapperNode
        }
        
        return nil
    }
}
