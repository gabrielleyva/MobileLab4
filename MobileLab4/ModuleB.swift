//
//  ModuleB.swift
//  MobileLab4
//
//  Created by Gabriel I Leyva Merino on 10/10/17.
//  Copyright © 2017 Leyva_Phadate. All rights reserved.
//

import Foundation
import UIKit
import Charts

class ModuleB: UIViewController {
    
    //MARK: Class Properties
    static let buffersize = 2048
    static let chartDuration  = 300
    static let samplingRate = Float(30.0*60)
    static let fftSize = 2048
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    let bridge = ModBBridge()
    var arrayMag = Array(repeating: Float(0), count: Int(buffersize/2))
    var dataBuffer = Buffer(with: chartDuration)
    var frame = 0
    var flashEnabled = false
    let fft = FFTHelper(fftSize: 2048, andWindow: WindowTypeHamming)
    let finder = PeakFinder(frequencyResolution: samplingRate / Float(fftSize))
    //MARK: Outlets in view

    @IBOutlet weak var bpmLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var lineChart: LineChartView!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        self.bpmLabel.isHidden = true
        self.view.backgroundColor = nil
        //self.setupFilters()
        
        //self.bridge.loadHaarCascade(withFilename: "nose")
        self.videoManager = VideoAnalgesic.sharedInstance
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImageFinger)
        
        if !videoManager.isRunning{
            videoManager.start()
            videoManager.setFPS(desiredFrameRate: 30)
        }
       self.setupLinechart()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        self.videoManager.stop()
    }
    
    func processImageFinger(inputImage: CIImage) -> CIImage {
 
        var retImage = inputImage
        let bounds = inputImage.extent
        self.bridge.setTransforms(self.videoManager.transform)
        
        self.bridge.setImage(retImage, withBounds: bounds,andContext: self.videoManager.getCIContext())
        let redIntensity = self.bridge.processImage()
        retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)
        

        // Check low light and turn on flash after 1 sec
        if (redIntensity < 80 && frame > 30 && !self.flashEnabled){
            _ = self.videoManager.turnOnFlashwithLevel(1.0)
            self.flashEnabled = true
            DispatchQueue.main.async {
                self.messageLabel.isHidden = true
                self.bpmLabel.isHidden = false
            }
            self.frame = 0
        }

        // Check finger moved and turn off flash light in 1
        if (redIntensity > 100 && redIntensity < 200 && frame > 30 && self.flashEnabled){
            self.videoManager.turnOffFlash()
            self.flashEnabled = false
            DispatchQueue.main.async {
                self.messageLabel.isHidden = false
                self.bpmLabel.isHidden = true
                self.bpmLabel.text = "Calculating Heart Rate..."
            }
            self.frame = 0
            self.dataBuffer.reset()
            self.lineChart.data = nil
        }

        // Check high red and wait 2 sec before red sattles
        if (redIntensity > 220 && frame > 60 && flashEnabled){
            self.dataBuffer.add(point: redIntensity)
        }

        // Every 3 seconds try to get fft
        let size = dataBuffer.getBufferCount()
        if (self.frame % (30*3) == 0 && size  != 0) {
            
            let data = self.dataBuffer.getData()
            let pad_size = ModuleB.buffersize - data.count
            var zeroPaddedData = data + Array(repeating: Float(0), count: pad_size)

            fft!.performForwardFFT(withData: &zeroPaddedData, andCopydBMagnitudeToBuffer: &arrayMag)

            var peaks = finder!.getFundamentalPeaks(fromBuffer: &arrayMag, withLength: UInt(Int(ModuleB.buffersize/2)),
                                                    usingWindowSize: 15, andPeakMagnitudeMinimum: 20, aboveFrequency: 60.0)

            if (peaks != nil){
                if peaks!.count > 0 {
                    let peak1: Peak = peaks![0] as! Peak
                    let res = Float(ModuleB.samplingRate) / Float(ModuleB.fftSize)
                    if peak1.frequency < 200{
                        DispatchQueue.main.async {
                            self.bpmLabel.text = String(Int(peak1.frequency))+" BPM"
                        }
                    }
                    
                   // print(arrayMag.max())
                    print("Freq resolution",res)
                    print("Heart rate is ",peak1.frequency, " Frame: ", self.frame)

                }
            }
        }
        
        // Update chart every 0.5 sec
        if(self.frame % 15 == 0 && self.flashEnabled){
            DispatchQueue.main.async {
                self.updateChart()
            }
        }
        self.frame += 1
        if self.frame >= ModuleB.chartDuration+30{ self.frame = 30 } // refresh frame every 10 sec
        return retImage
        
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        return inputImage
    }
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        _ = self.videoManager.toggleFlash()
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
    
    //MARK: Linechart methods
    func updateChart(){
        
        var lineChartEntry = [ChartDataEntry]()
        let data = self.dataBuffer.getData()
        for i in 0..<data.count{
            let value = ChartDataEntry(x: Double(i), y: Double(data[i]))
            lineChartEntry.append(value)
        }
        
        let line1 = LineChartDataSet(values: lineChartEntry, label: nil)
        line1.colors = [NSUIColor.red]
        line1.drawCirclesEnabled = false
        line1.drawValuesEnabled = false
        let lineData = LineChartData()
        lineData.addDataSet(line1)
        self.lineChart.data = lineData
    }
    
    func setupLinechart() {
        self.lineChart.backgroundColor = UIColor.black
        self.lineChart.leftAxis.drawAxisLineEnabled = false
        self.lineChart.rightAxis.drawAxisLineEnabled = false
        self.lineChart.xAxis.drawAxisLineEnabled = false
        self.lineChart.noDataTextColor = UIColor.white
        self.lineChart.noDataText = "Waiting to get pulse data"
        self.lineChart.xAxis.drawGridLinesEnabled = false
        self.lineChart.rightAxis.drawGridLinesEnabled = false
        self.lineChart.leftAxis.drawGridLinesEnabled = false
        self.lineChart.legend.enabled = false
        self.lineChart.minOffset = 0
        self.lineChart.drawBordersEnabled = false
    }
    
    
    

    
}
