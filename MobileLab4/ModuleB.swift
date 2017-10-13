//
//  ModuleB.swift
//  MobileLab4
//
//  Created by Gabriel I Leyva Merino on 10/10/17.
//  Copyright © 2017 Leyva_Phadate. All rights reserved.
//

import Foundation
import UIKit

class ModuleB: UIViewController {
    
    //MARK: Class Properties
    static let buffersize = 2048
    static let samplingRate = Float(30.0*60)
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = ModBBridge()
    var array = Array(repeating: Float(0), count: buffersize)
    var arrayMag = Array(repeating: Float(0), count: Int(buffersize/2))
    var count = 0
    var delay = 0
    static let fftSize = 2048
    let fft = FFTHelper(fftSize: 2048)
    let finder = PeakFinder(frequencyResolution: samplingRate / Float(fftSize))
    //MARK: Outlets in view
    @IBOutlet weak var flashSlider: UISlider!
    @IBOutlet weak var stageLabel: UILabel!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        //self.setupFilters()
        
        //self.bridge.loadHaarCascade(withFilename: "nose")
        self.videoManager = VideoAnalgesic.sharedInstance
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back
        )
        
        // create dictionary for face detection
        // HINT: you need to manipulate these proerties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyHigh,CIDetectorTracking:true] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                   context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImageFinger)
        
        if !videoManager.isRunning{
            videoManager.start()
            videoManager.setFPS(desiredFrameRate: 30)
        }
        
    }
    
    func processImageFinger(inputImage: CIImage) -> CIImage {
        
        
        var retImage = inputImage
        let bounds = inputImage.extent
        self.bridge.setTransforms(self.videoManager.transform)
        
        //print(bounds)
        self.bridge.setImage(retImage, withBounds: bounds,andContext: self.videoManager.getCIContext())
        let f = self.bridge.processImage()
        retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)
        self.delay+=1
        if (f < 50 && delay > 60){
            _ = self.videoManager.turnOnFlashwithLevel(1.0)
            self.delay = 0
        }
        if (f > 50 && f < 200){
            self.videoManager.turnOffFlash()
            self.delay = 0
        }
        if (f > 220 && delay > 60){
            self.array[self.count] = f
            self.count += 1
            if (self.count  == 300 ){
                self.count = 0
            }
            if (delay >= 100){
                delay = 60
            }
        }
            
        if (count % (30*3) == 0) {
            fft!.performForwardFFT(withData: &array, andCopydBMagnitudeToBuffer: &arrayMag)
            
            var peaks = finder!.getFundamentalPeaks(fromBuffer: &arrayMag, withLength: UInt(Int(ModuleB.buffersize/2)), usingWindowSize: 10, andPeakMagnitudeMinimum: 10, aboveFrequency: 50.0)
            
            if (peaks != nil){
                if peaks!.count > 0 {
                    let peaks2:[Peak] = peaks as! [Peak]
                    let peak1: Peak = peaks![0] as! Peak
                    let res = Float(ModuleB.samplingRate) / Float(ModuleB.fftSize)
                    let max = arrayMag[0...300].max()!
                    
                    for i in 0..<peaks!.count {
                        print(peaks2[i].frequency)
                    }
                    
                    print("Max value: ",max)
                    print("Freq resolution",res)
                    print("Heart rate is ",peak1.frequency, " Count: ", self.count)
                    
                    
                        DispatchQueue.main.async {
                            if (peak1.frequency < 210){
                            self.stageLabel.text = String(Int(peak1.frequency))+" BPM"
                            }
//                            else{
//                                self.stageLabel.text = "Calculating Heart Rate..."
//                            }
                    }
                }
                
                //print("Band width: ", arrayMag)
            }
                
            
            
        }
        
        //print(self.array)
        return retImage
        
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        
        // detect faces
        let f = getFaces(img: inputImage)
        
        
        // if no faces, just return original image
        
        if f.count == 0 { return inputImage }
        
        var retImage = inputImage
        
        // if you just want to process on separate queue use this code
        // this is a NON BLOCKING CALL, but any changes to the image in OpenCV cannot be displayed real time
        //        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) { () -> Void in
        //            self.bridge.setImage(retImage, withBounds: retImage.extent, andContext: self.videoManager.getCIContext())
        //            self.bridge.processImage()
        //        }
        
        // use this code if you are using OpenCV and want to overwrite the displayed image via OpenCv
        // this is a BLOCKING CALL
        //        self.bridge.setTransforms(self.videoManager.transform)
        //        self.bridge.setImage(retImage, withBounds: retImage.extent, andContext: self.videoManager.getCIContext())
        //        self.bridge.processImage()
        //        retImage = self.bridge.getImage()
        
        //HINT: you can also send in the bounds of the face to ONLY process the face in OpenCV
        // or any bounds to only process a certain bounding region in OpenCV
        
        
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage,
                             withBounds: f[0].bounds, // the first face bounds
            andContext: self.videoManager.getCIContext())
        
        self.bridge.processImage()
        retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)
        
        return retImage
    }
    
    //MARK: Setup filtering
    //    func setupFilters(){
    //        filters = []
    //
    //        let filterPinch = CIFilter(name:"CIBumpDistortion")!
    //        filterPinch.setValue(-0.5, forKey: "inputScale")
    //        filterPinch.setValue(75, forKey: "inputRadius")
    //        filters.append(filterPinch)
    //
    //    }
    
    //MARK: Apply filters and apply feature detectors
    //    func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
    //        var retImage = inputImage
    //        var filterCenter = CGPoint()
    //
    //        for f in features {
    //            //set where to apply filter
    //            filterCenter.x = f.bounds.midX
    //            filterCenter.y = f.bounds.midY
    //
    //            //do for each filter (assumes all filters have property, "inputCenter")
    //            for filt in filters{
    //                filt.setValue(retImage, forKey: kCIInputImageKey)
    //                filt.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
    //                // could also manipualte the radius of the filter based on face size!
    //                retImage = filt.outputImage!
    //            }
    //        }
    //        return retImage
    //    }
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        //let optsFace = [CIDetectorImageOrientation:self.videoManager.getImageOrientationFromUIOrientation(UIApplication.sharedApplication().statusBarOrientation)]
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
        
        
    }
    
    
    
    
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        if(self.videoManager.toggleFlash()){
            self.flashSlider.value = 1.0
        }
        else{
            self.flashSlider.value = 0.0
        }
    }
    
    @IBAction func switchCamera(_ sender: AnyObject) {
        
        self.videoManager.toggleCameraPosition()
        switch self.videoManager.getCameraPosition(){
        case AVCaptureDevice.Position.back:
            self.videoManager.setProcessingBlock(newProcessBlock: self.processImageFinger)
            print("Finger")
        case AVCaptureDevice.Position.front:
            self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
            print("Face")
        default:
            self.videoManager.setProcessingBlock(newProcessBlock: self.processImageFinger)
            print("Something went wrong")
        }
    }
    
    @IBAction func setFlashLevel(_ sender: UISlider) {
        if(sender.value>0.0){
            self.videoManager.turnOnFlashwithLevel(sender.value)
        }
        else if(sender.value==0.0){
            self.videoManager.turnOffFlash()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        if videoManager.isRunning{
            self.videoManager.stop()
        }
    }
    
    
    
}
