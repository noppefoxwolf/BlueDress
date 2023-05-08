//
//  ViewController.swift
//  Example
//
//  Created by Tomoya Hirano on 2020/12/28.
//

import UIKit
import AVFoundation
import BlueDress

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let camera = Camera()
    let displayLayer = AVSampleBufferDisplayLayer()
    let blueDress = try! YCbCrImageBufferConverter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        camera.output.setSampleBufferDelegate(self, queue: .main)
        camera.session.startRunning()
        view.layer.addSublayer(displayLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        displayLayer.frame = view.bounds
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var timingInfo: CMSampleTimingInfo = .invalid
        let timingInfoSuccess = CMSampleBufferGetSampleTimingInfo(sampleBuffer, at: 0, timingInfoOut: &timingInfo)
        print(timingInfoSuccess == noErr)
        
        let original = sampleBuffer.imageBuffer!
        let converted = try! blueDress.convertToBGRA(imageBuffer: original)
        
        let dataIsReady = CMSampleBufferDataIsReady(sampleBuffer)
        let refCon = NSMutableData()
        
        var formatDescription: CMVideoFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: converted, formatDescriptionOut: &formatDescription)
        
        var output: CMSampleBuffer? = nil
        let status = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: converted, dataReady: dataIsReady, makeDataReadyCallback: nil, refcon: refCon.mutableBytes, formatDescription: formatDescription!, sampleTiming: &timingInfo, sampleBufferOut: &output)
        print(status, status == noErr)
        displayLayer.enqueue(output!)
    }
}

class Camera {
    lazy var device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front).devices[0]
    lazy var input = try! AVCaptureDeviceInput(device: device)
    lazy var output = AVCaptureVideoDataOutput()
    lazy var session = AVCaptureSession()
    
    init() {
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        session.addInput(input)
        session.addOutput(output)
    }
}
