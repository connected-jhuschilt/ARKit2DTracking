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
            
            sceneView.session.run(configuration)
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
                        let hitTestResults = frame.hitTest(center, types: [ARHitTestResult.ResultType.existingPlane])  //featurePoint
                        
                        // If we have a result, process it
                        if let hitTestResult = hitTestResults.first {
                            
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
