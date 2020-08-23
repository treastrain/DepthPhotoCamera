//
//  DepthPreviewViewController.swift
//  DepthPhotoCamera
//
//  Created by treastrain on 2020/08/23.
//

import UIKit
import AVFoundation

class DepthPreviewViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var photo: AVCapturePhoto!
    var image: UIImage!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var depthImageView: UIImageView!
    @IBOutlet weak var saveToCameraRollButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let imageData = self.photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("imageData || image is/are nil.")
            return
        }
        self.image = image
        self.imageView.image = image
        
        guard let depthPixelBuffer = self.photo.depthData?.convertToDepth().depthDataMap,
              let depthMapImage = UIImage(pixelBuffer: depthPixelBuffer, orientation: image.imageOrientation) else {
            print("depthPixelBuffer || depthMapImage is/are nil.")
            return
        }
        DispatchQueue.main.async {
            self.depthImageView.image = depthMapImage
        }
    }
    
    @IBAction func saveToCameraRoll() {
        self.saveToCameraRollButton.setTitle("Saving...", for: .normal)
        self.saveToCameraRollButton.isEnabled = false
        UIImageWriteToSavedPhotosAlbum(self.image, self, #selector(self.image(image:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(image: UIImage, didFinishSavingWithError error: Error?, contextInfo: AnyObject) {
        if let error = error {
            let alertController = UIAlertController(title: "Save Error", message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alertController, animated: true)
            self.saveToCameraRollButton.setTitle("Save to Camera Rool", for: .normal)
            self.saveToCameraRollButton.isEnabled = true
        } else {
            self.saveToCameraRollButton.setTitle("✅ Saved", for: .normal)
        }
    }
}


// 参考: https://github.com/shu223/iOS-Depth-Sampler
extension AVDepthData {
    func convertToDepth() -> AVDepthData {
        let targetType: OSType
        switch depthDataType {
        case kCVPixelFormatType_DisparityFloat16:
            targetType = kCVPixelFormatType_DepthFloat16
        case kCVPixelFormatType_DisparityFloat32:
            targetType = kCVPixelFormatType_DepthFloat32
        default:
            return self
        }
        return converting(toDepthDataType: targetType)
    }
}

// 参考: https://github.com/shu223/iOS-Depth-Sampler
extension UIImage {
    convenience init?(pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let pixelBufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let pixelBufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let imageRect:CGRect = CGRect(x: 0, y: 0, width: pixelBufferWidth, height: pixelBufferHeight)
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(ciImage, from: imageRect) else {
            return nil
        }
        self.init(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
}
