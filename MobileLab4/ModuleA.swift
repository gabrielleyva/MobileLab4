//
//  ModuleA.swift
//  MobileLab4
//
//  Created by Gabriel I Leyva Merino on 10/10/17.
//  Copyright © 2017 Leyva_Phadate. All rights reserved.
//

import Foundation
import UIKit
import AVKit

class ModuleA: UIViewController {
    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    var detector:CIDetector! = nil
    
    let pinchFilterIndex = 2
    let bridge = OpenCVBridge()
    
    //MARK: Outlets in view
    @IBOutlet weak var smileLabel: UILabel!
    @IBOutlet weak var BlinkLabel: UILabel!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.prepareLabels()
        
        self.videoManager = VideoAnalgesic.sharedInstance
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.front)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these proerties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                   context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: optsDetector)
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
        
        self.bridge.processType = 4
        
    }
    
    func prepareLabels() {
        BlinkLabel.textColor = .white
        smileLabel.textColor = .white
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        
        // detect faces
        let f = getFaces(img: inputImage)
        
        // if no faces, just return original image
        if f.count == 0 { return inputImage }
        
        var retImage = inputImage
    
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage,
                             withBounds: retImage.extent, // the first face bounds
            andContext: self.videoManager.getCIContext())
        
        self.bridge.processImage()
        retImage = self.bridge.getImageComposite()
        
        //detect smile of first face
        detectSmile(f: f[0])
        detectBlinking(f: f[0])

        //applying all filters
        let leftEyeImage = applyEyeFilter(inputImage: retImage, features: f, leftEye: true)
        let rightEyeImage = applyEyeFilter(inputImage: leftEyeImage, features: f, leftEye: false)
        let mouthImage = applyMouthFilter(inputImage: rightEyeImage, features: f)
        let faceImage = applyFiltersToFaces(inputImage: mouthImage, features: f)
        
        return faceImage
    }
    
    //MARK: Detect Smiling and Blinking
    func detectSmile(f: CIFaceFeature){
        if f.hasSmile {
            DispatchQueue.main.async {
                self.smileLabel.text = "Smile: Yes"
            }
        } else {
            DispatchQueue.main.async {
                self.smileLabel.text = "Smile: No"
            }
        }
    }
    
    func detectBlinking(f: CIFaceFeature){
        if f.rightEyeClosed  && f.leftEyeClosed {
            DispatchQueue.main.async {
                self.BlinkLabel.text = "Blink: Both Eyes"
            }
        } else if f.leftEyeClosed {
            DispatchQueue.main.async {
                self.BlinkLabel.text = "Blink: Left Eye"
            }
        } else if f.rightEyeClosed {
            DispatchQueue.main.async {
                self.BlinkLabel.text = "Blink: Right Eye"
            }
        } else {
            DispatchQueue.main.async {
                self.BlinkLabel.text = "Blink: None"
            }
        }
    }
    
    
    //MARK: Apply filters and apply feature detectors
    func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
        var retImage = inputImage
        var filterCenter = CGPoint()
        
        let pinch = CIFilter(name:"CIBumpDistortion")!
        pinch.setValue(-0.5, forKey: "inputScale")
        pinch.setValue(85, forKey: "inputRadius")
        pinch.setValue(retImage, forKey: kCIInputImageKey)
        
        for f in features {
            //set where to apply filter
            filterCenter.x = f.bounds.midX
            filterCenter.y = f.bounds.midY
            
            pinch.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
            
            retImage = pinch.outputImage!
            
        }
        return retImage
    }
    
    func applyEyeFilter(inputImage: CIImage,features: [CIFaceFeature], leftEye: Bool)-> CIImage{
        var retImage = inputImage
        var filterCenter = CGPoint()
        
        let expand = CIFilter(name:"CIBumpDistortion")!
        expand.setValue(0.5, forKey: "inputScale")
        expand.setValue(60, forKey: "inputRadius")
        expand.setValue(retImage, forKey: kCIInputImageKey)
        
        for f in features {
            
            if f.hasLeftEyePosition && leftEye == true{
                //set where to apply filter
                filterCenter.x = f.leftEyePosition.x
                filterCenter.y = f.leftEyePosition.y
                
                expand.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
                
                retImage = expand.outputImage!
                
            } else if f.hasRightEyePosition && leftEye == false {
                //set where to apply filter
                filterCenter.x = f.rightEyePosition.x
                filterCenter.y = f.rightEyePosition.y
                
                expand.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
                
                retImage = expand.outputImage!
            }
        }
        return retImage
    }
    
    func applyMouthFilter(inputImage: CIImage,features: [CIFaceFeature])-> CIImage {
        var retImage = inputImage
        var filterCenter = CGPoint()
        
        let pixelate = CIFilter(name:"CIHoleDistortion")!
        pixelate.setValue(20 , forKey: "inputRadius")
        pixelate.setValue(retImage, forKey: kCIInputImageKey)
        
        for f in features {
            if f.hasMouthPosition {
                filterCenter.x = f.mouthPosition.x
                filterCenter.y = f.mouthPosition.y
                
                pixelate.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
                
                retImage = pixelate.outputImage!
            }
        }
        
        return retImage
        
    }
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // get Face Features
        return self.detector.features(in: img, options: [CIDetectorSmile: true, CIDetectorEyeBlink: true, CIDetectorImageOrientation : self.videoManager.ciOrientation]) as! [CIFaceFeature]
    }
}
