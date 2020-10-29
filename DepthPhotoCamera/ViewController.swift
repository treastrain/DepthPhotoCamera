//
//  ViewController.swift
//  DepthPhotoCamera
//
//  Created by treastrain on 2020/08/23.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    @IBOutlet weak var captureButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.captureButton.isEnabled = false
        self.view.backgroundColor = .darkGray
        self.setup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.session.startRunning()
        self.captureButton.isEnabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureButton.isEnabled = false
        self.session.stopRunning()
    }
    
    func setup() {
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .unspecified) ?? AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .unspecified) else {
            print("No dual camera.")
            return
        }
        guard let videoCaptureDeviceInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              self.session.canAddInput(videoCaptureDeviceInput) else {
            print("Can't add video input.")
            return
        }
        self.session.addInput(videoCaptureDeviceInput)
        
        guard self.session.canAddOutput(self.photoOutput) else {
            print("Can't add photo output.")
            return
        }
        self.session.addOutput(self.photoOutput)
        self.session.sessionPreset = .photo
        self.photoOutput.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliverySupported
        self.session.beginConfiguration()
        self.session.commitConfiguration()
        
        self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.videoPreviewLayer.videoGravity = .resizeAspectFill
        self.videoPreviewLayer.connection?.videoOrientation = .portrait
        self.videoPreviewLayer.frame = self.view.frame
        self.view.layer.insertSublayer(self.videoPreviewLayer, at: 0)
    }
    
    @IBAction func capture() {
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        photoSettings.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliverySupported
        self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        self.captureButton.isEnabled = false
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("photo:", photo)
        print("photo.depthData:", photo.depthData ?? "nil")
        
        self.performSegue(withIdentifier: "toDepthPreviewVC", sender: photo)
        self.captureButton.isEnabled = true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toDepthPreviewVC",
           let photo = sender as? AVCapturePhoto,
           let depthPreviewViewController = segue.destination as? DepthPreviewViewController {
            depthPreviewViewController.photo = photo
        }
    }
}
