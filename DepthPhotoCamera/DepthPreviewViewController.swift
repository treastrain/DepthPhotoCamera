//
//  DepthPreviewViewController.swift
//  DepthPhotoCamera
//
//  Created by treastrain on 2020/08/23.
//

import UIKit
import AVFoundation
import Zip

class DepthPreviewViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var photo: AVCapturePhoto!
    
    var image: UIImage! {
        didSet {
            if image == nil {
                self.imageLabel.text = "image ❌"
            } else {
                self.imageLabel.text = "image ✅"
            }
        }
    }
    var depthImage: UIImage? {
        didSet {
            if depthImage == nil {
                self.depthLabel.text = "depth ❌"
            } else {
                self.depthLabel.text = "depth ✅"
            }
        }
    }
    
    var jpegImage: UIImage!
    var pngDepthImage: UIImage!
    
    @IBOutlet weak var imageLabel: UILabel!
    @IBOutlet weak var depthLabel: UILabel!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var depthImageView: UIImageView!
    
    @IBOutlet weak var saveInZipButton: UIButton!
    @IBOutlet weak var saveToCameraRollButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.image = nil
        self.depthImage = nil
        
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
        self.depthImage = depthMapImage
        self.depthImageView.image = depthMapImage
    }
    
    @IBAction func saveInZip(_ sender: UIButton) {
        sender.isEnabled = false
        sender.setTitle("Saving...", for: .normal)
        
        let tmpPath = NSTemporaryDirectory()
        var paths: [URL] = []
        
        // HEIC 画像の一時保存
        if let heicData = self.photo?.fileDataRepresentation() as NSData? {
            let path = "\(tmpPath)image.heic"
            heicData.write(toFile: path, atomically: true)
            paths.append(URL(fileURLWithPath: path))
        }
        
        // JPEG 画像の一時保存
        if let jpegData = self.image?.jpegData(compressionQuality: 1.0) as NSData? {
            let path = "\(tmpPath)image.jpg"
            jpegData.write(toFile: path, atomically: true)
            paths.append(URL(fileURLWithPath: path))
        }
        
        // Depth を PNG で一時保存
        if let pngDepthData = self.depthImage?.flattenedPngData() as NSData? {
            let path = "\(tmpPath)depth.png"
            pngDepthData.write(toFile: path, atomically: true)
            paths.append(URL(fileURLWithPath: path))
        }
        
        // ZIP を一時保存
        let documentsUrl = FileManager.default.temporaryDirectory
        let destinationUrl = documentsUrl.appendingPathComponent("\(Date().string).zip")
        do {
            try Zip.zipFiles(paths: paths, zipFilePath: destinationUrl, password: nil, progress: { (progress) in
                print("progress:", progress)
            })
            
            // 共有
            let activityViewController = UIActivityViewController(activityItems: [destinationUrl], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            activityViewController.popoverPresentationController?.sourceRect = self.saveInZipButton.frame
            self.present(activityViewController, animated: true) {
                sender.setTitle("Re-save in ZIP", for: .normal)
                sender.isEnabled = true
            }
        } catch {
            let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alertController, animated: true) {
                sender.setTitle("Save in ZIP", for: .normal)
                sender.isEnabled = true
            }
        }
    }
    
    @IBAction func saveToCameraRoll() {
        self.saveToCameraRollButton.setTitle("Saving...", for: .normal)
        self.saveToCameraRollButton.isEnabled = false
        
        // HEIC 画像の保存
        UIImageWriteToSavedPhotosAlbum(self.image, self, #selector(self.image(image:didFinishSavingWithError:contextInfo:)), nil)
        
        // JPEG 画像の保存
        let jpegData = self.image.jpegData(compressionQuality: 1.0)!
        self.jpegImage = UIImage(data: jpegData)!
        UIImageWriteToSavedPhotosAlbum(self.jpegImage, self, #selector(self.image(image:didFinishSavingWithError:contextInfo:)), nil)
        
        // Depth を PNG で保存
        if let depthImage = self.depthImage {
            let pngData = depthImage.flattenedPngData()!
            self.pngDepthImage = UIImage(data: pngData)!
            UIImageWriteToSavedPhotosAlbum(self.pngDepthImage, self, #selector(self.image(image:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    var heicStatus = "❌"
    var jpegStatus = "❌"
    var pngDepthStatus = "❌"
    var statusCount = 0 {
        didSet {
            if statusCount == 3 || (statusCount == 2 && self.depthImage == nil) {
                statusCount = 0
                let message = "HEIC: \(heicStatus)\nJPEG: \(jpegStatus)\nPNG (depth): \(pngDepthStatus)"
                let alertController = UIAlertController(title: "Results", message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alertController, animated: true)
                self.saveToCameraRollButton.setTitle("Save to Camera Rool", for: .normal)
                self.saveToCameraRollButton.isEnabled = true
            }
        }
    }
    @objc func image(image: UIImage, didFinishSavingWithError error: Error?, contextInfo: AnyObject) {
        var status = ""
        if let error = error {
            status = "❌ \(error.localizedDescription)"
        } else {
            status = "✅ Saved"
        }
        
        switch image {
        case self.image:
            heicStatus = status
        case self.jpegImage:
            jpegStatus = status
        case self.pngDepthImage:
            pngDepthStatus = status
        default:
            fatalError()
        }
        
        self.statusCount += 1
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

// 参考: https://stackoverflow.com/questions/42098390/swift-png-image-being-saved-with-incorrect-orientation
extension UIImage {
    func flattened() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        let format = self.imageRendererFormat
        format.opaque = true
        return UIGraphicsImageRenderer(size: self.size, format: format).image { _ in
            draw(at: .zero)
        }
    }
    
    func flattenedPngData() -> Data? {
        return self.flattened().pngData()
    }
}

extension Date {
    var string: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: self)
    }
}
