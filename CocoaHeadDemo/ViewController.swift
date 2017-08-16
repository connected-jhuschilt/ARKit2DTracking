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
    
    private var rectanglesToTrack = [Rectangle]()
    private var runningDetectRectangleRequest = false
    
    
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
        if AROrientationTrackingConfiguration.isSupported {
            let configuration = AROrientationTrackingConfiguration()
            
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
    
    lazy var detectRectanglesRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest(completionHandler: self.handleRectangleDetection)
        
        request.minimumSize = 0.2
        request.maximumObservations = 1
        
        return request
    }()
    
    // callback
    func handleRectangleDetection(request: VNRequest, error: Error?) {
        self.runningDetectRectangleRequest = false
        
        if let error = error {
            print("Rectangle Detection Request Error: \(error.localizedDescription)")
            return
        }
        
        guard let observations = request.results as? [VNRectangleObservation] else {
            print("Unexpected Observation type")
            return
        }
        
        // TODO: Change to for loop for multiple detections
        if let newRectangleObservation = observations.first {
            updateRectangle(detectedObservation: newRectangleObservation)
        }
    }
    
    func buildTrackRequest(for rectangle: VNRectangleObservation) -> VNTrackRectangleRequest {
        return VNTrackRectangleRequest(rectangleObservation: rectangle, completionHandler: self.handleTrackRectangles)
    }
    
    func updateRectangle(detectedObservation: VNRectangleObservation) {
        print("updateRectangle  rectanglesToTrack.count: \(rectanglesToTrack.count)    center: \(detectedObservation.center)    boundingBox: \(detectedObservation.boundingBox)")
        
        // if this is a new rectangle, and should be tracked
        if nil  == rectanglesToTrack.first(where: { (trackedRectangle) in
            let centerDifference = trackedRectangle.observation.center.distance(to: detectedObservation.center)
            
            // TODO: Experiment with a value that is within a margin of error (find out unit measurement)
            return centerDifference < 5
        }) {
            // TODO: Filter out unwanted rectangles (ie. by: size, confidence)
            rectanglesToTrack.append(Rectangle(initialObservation: detectedObservation, trackRequest: buildTrackRequest(for: detectedObservation)))
        }
    }
    
    // callback
    func handleTrackRectangles(request: VNRequest, error: Error?){
        if let error = error {
            // TODO: Remove the rectangle from the array of trackedRectangles if tracking lost forever
            print("Track Rectangle Request Error: \(error.localizedDescription)")
            return
        }
        
        // TODO: Do something with tracking info
        // update observations, show toast
        
        
        
        if let trackedObservation = request.results?.first as? VNRectangleObservation {
            print("        UUID: \(String(describing: trackedObservation.uuid))")
            print("        Center: \(String(describing: trackedObservation.center))  \(trackedObservation.boundingBox)")
            
            if let rectangle = rectanglesToTrack.first(where: { $0.trackRequest == request && $0.observation.uuid == trackedObservation.uuid })
            {
                rectangle.observation = trackedObservation
            }
        }
    }
    
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // TODO: Notify the user through an indicator if the tracking state is limited
        print("cameraDidChangeTrackingState: \(camera.trackingState)")
    }
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Process the request in the background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let strongSelf = self else { return }
            
            var requests = [VNRequest]()
            
            // always run tracking requests
            requests += strongSelf.rectanglesToTrack.map({ $0.trackRequest })
            
            // Only run a new detect request if there aren't any currently running
            if !strongSelf.runningDetectRectangleRequest {
                strongSelf.runningDetectRectangleRequest = true
                requests.append(strongSelf.detectRectanglesRequest)
            }
            
            do {
                // Create a request handler using the captured image from the ARFrame
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                                                options: [:])
                // Process the requests
                try imageRequestHandler.perform(requests)
            } catch {
                print("Error starting Vision Requests: \(error.localizedDescription)")
            }
        }
    }
}
