

import UIKit
import AVFoundation

import Vision

class ViewController: UIViewController {

  @IBOutlet weak var videoView: UIView!
  
  lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
  lazy var captureSession: AVCaptureSession = {
    let session = AVCaptureSession()
    session.sessionPreset = AVCaptureSession.Preset.photo
    guard
      let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: backCamera)
      else { return session }
    session.addInput(input)
    return session
  }()
  var maskLayer = [CAShapeLayer]()
  var devicePosition: AVCaptureDevice.Position = .back
  
  override func viewDidLoad() {
    super.viewDidLoad()
    videoView.layer.addSublayer(cameraLayer)
    
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
    captureSession.addOutput(videoOutput)
    captureSession.startRunning()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    cameraLayer.frame = videoView?.bounds ?? .zero
  }
  
  func handleFaces(request: VNRequest, error: Error?) {
    //get results.
    guard let observations = request.results as? [VNFaceObservation] else {
      fatalError("Unexpected result type from request.")
    }
    if let newObservation = observations.first {
      DispatchQueue.main.async {
        self.removeMask()
        self.drawHighlight(boundingBox: newObservation.boundingBox)
      }
    }
    //oh no it doesn't work? what do we need?
  }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    // make sure the pixel buffer can be converted
    guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let exifOrientation = CGImagePropertyOrientation(rawValue: exifOrientationFromDeviceOrientation()) else { return }
    
    var requestOptions: [VNImageOption : Any] = [:]
    if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
      requestOptions = [.cameraIntrinsics : cameraIntrinsicData]
    }
    
    // Step 1 get request

    
    let faceRequest = VNDetectFaceRectanglesRequest(completionHandler: handleFaces)
    
    //step 2 pass it to handler ... Is this missing something??
    let imageHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestOptions)
    DispatchQueue.global(qos: .userInteractive).async {
      do {
        try imageHandler.perform([faceRequest])
      } catch {
        print("Image handler error \(error).")
      }
    }
  }
    //tracking is the same thing.
}

extension ViewController {
  func exifOrientationFromDeviceOrientation() -> UInt32 {
    enum DeviceOrientation: UInt32 {
      case top0ColLeft = 1
      case top0ColRight = 2
      case bottom0ColRight = 3
      case bottom0ColLeft = 4
      case left0ColTop = 5
      case right0ColTop = 6
      case right0ColBottom = 7
      case left0ColBottom = 8
    }
    var exifOrientation: DeviceOrientation
    
    switch UIDevice.current.orientation {
    case .portraitUpsideDown:
      exifOrientation = .left0ColBottom
    case .landscapeLeft:
      exifOrientation = devicePosition == .front ? .bottom0ColRight : .top0ColLeft
    case .landscapeRight:
      exifOrientation = devicePosition == .front ? .top0ColLeft : .bottom0ColRight
    default:
      exifOrientation = .right0ColTop
    }
    return exifOrientation.rawValue
  }
  
  func drawHighlight(boundingBox: CGRect) {
    let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -videoView.frame.height)
    let translate = CGAffineTransform.identity.scaledBy(x: videoView.frame.width, y: videoView.frame.height)
    let facebounds = boundingBox.applying(translate).applying(transform)
    _ = createLayer(in: facebounds)
  }
  
  func createLayer(in rect: CGRect) -> CAShapeLayer{
    let mask = CAShapeLayer()
    mask.frame = rect
    mask.cornerRadius = 10
    mask.opacity = 0.75
    mask.borderColor = UIColor.green.cgColor
    mask.borderWidth = 2.0
    
    maskLayer.append(mask)
    cameraLayer.insertSublayer(mask, at: 1)
    
    return mask
  }
  
  func removeMask() {
    for mask in maskLayer {
      mask.removeFromSuperlayer()
    }
    maskLayer.removeAll()
  }

}
