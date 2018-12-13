import UIKit
import Vision
import AVFoundation
import CoreMedia
import VideoToolbox

class ViewController: UIViewController {
  @IBOutlet weak var videoPreview: UIView!
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var debugImageView: UIImageView!
  
  let yolo = YOLO()
  let tracker =  Sort()
  
//  let aspectRatioWidth :CGFloat = 3
//  let aspectRatioHeight :CGFloat = 4
//  let sessionPreset = AVCaptureSession.Preset.vga640x480
  
  let aspectRatioWidth :CGFloat = 9
  let aspectRatioHeight :CGFloat = 16
  let sessionPreset = AVCaptureSession.Preset.hd1280x720
  
  var videoCapture: VideoCapture!
  var request: VNCoreMLRequest!
  var startTimes: [CFTimeInterval] = []
  
  var boundingBoxes = [BoundingBox]()
  var trackBoxes = [BoundingBox]()
  var line = Line()
  var counter = Counter()
  
  var colors: [UIColor] = []
  
  var memory:Dictionary<Int, [CGFloat]> = [:]
  
  let ciContext = CIContext()
  var resizedPixelBuffer: CVPixelBuffer?
  
  var framesDone = 0
  var frameCapturingStartTime = CACurrentMediaTime()
  let semaphore = DispatchSemaphore(value: 2)
  
  var imageBuffers:[CVImageBuffer] = []
  var frame = 0
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    timeLabel.text = ""
    
    setUpBoundingBoxes()
    setUpTrackBoxes()
    setUpLine()
    setUpCoreImage()
    setUpVision()
    setUpCamera()
    
    // for testing:
    // (previously disable setUpCamera)
    // setUpVideo()
    
    frameCapturingStartTime = CACurrentMediaTime()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    print(#function)
  }
  
  // MARK: - Initialization
  
  func setUpBoundingBoxes() {
    for _ in 0..<YOLO.maxBoundingBoxes {
      boundingBoxes.append(BoundingBox())
    }
    
    // Make colors for the bounding boxes. There is one color for each class,
    // 80 classes in total.
    for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
      for g: CGFloat in [0.3, 0.7, 0.6, 0.8] {
        for b: CGFloat in [0.4, 0.8, 0.6, 1.0] {
          let color = UIColor(red: r, green: g, blue: b, alpha: 1)
          colors.append(color)
        }
      }
    }
  }
  
  func setUpTrackBoxes() {
    for _ in 0..<YOLO.maxBoundingBoxes {
      trackBoxes.append(BoundingBox())
    }
  }
  
  func setUpLine() {
    line.show(from: CGPoint(x: view.bounds.width/4, y: view.bounds.height/2), to: CGPoint(x: 3 * view.bounds.width/4, y: view.bounds.height/2))
  }
  
  func setUpCoreImage() {
    let status = CVPixelBufferCreate(nil, YOLO.inputWidth, YOLO.inputHeight,
                                     kCVPixelFormatType_32BGRA, nil,
                                     &resizedPixelBuffer)
    if status != kCVReturnSuccess {
      print("Error: could not create resized pixel buffer", status)
    }
  }
  
  func setUpVision() {
    guard let visionModel = try? VNCoreMLModel(for: yolo.model.model) else {
      print("Error: could not create Vision model")
      return
    }
    
    request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
    
    // NOTE: If you choose another crop/scale option, then you must also
    // change how the BoundingBox objects get scaled when they are drawn.
    // Currently they assume the full input image is used.
    request.imageCropAndScaleOption = .scaleFill
  }
  
  
  func setUpCamera() {
    videoCapture = VideoCapture()
    videoCapture.delegate = self
    videoCapture.fps = 50
    videoCapture.setUp(sessionPreset: sessionPreset) { success in
      if success {
        // Add the video preview into the UI.
        if let previewLayer = self.videoCapture.previewLayer {
          self.videoPreview.layer.addSublayer(previewLayer)
          self.resizePreviewLayer()
        }
        
        self.setUpLayers()
        
        // Once everything is set up, we can start capturing live video.
        self.videoCapture.start()
      }
    }
  }
  
  func setUpLayers() {
    // Add the bounding box layers to the UI, on top of the video preview.
    
    line.addToLayer(videoPreview.layer)
    counter.addToLayer(videoPreview.layer)
    
    for box in boundingBoxes {
      box.addToLayer(videoPreview.layer)
    }
    
    for box in trackBoxes {
      box.addToLayer(videoPreview.layer)
    }
  }
  
  func setUpVideo() {
    let asset = AVAsset(url: URL(fileReferenceLiteralResourceName: "traffic.mp4"))
    let reader = try! AVAssetReader(asset: asset)

    let videoTrack = asset.tracks(withMediaType: AVMediaType.video)[0]

    // read video frames as BGRA
    let trackReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings:[String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)])

    reader.add(trackReaderOutput)
    reader.startReading()
    
    while let sampleBufferRef = trackReaderOutput.copyNextSampleBuffer() {
      if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBufferRef) {
        // process each CVPixelBufferRef here
        // see CVPixelBufferGetWidth, CVPixelBufferLockBaseAddress, CVPixelBufferGetBaseAddress, etc
        imageBuffers.append(imageBuffer)
      }
    }
    reader.cancelReading()
    renderFrame()
  }
  
  func renderNextFrame() {
    frame += 1
    renderFrame()
  }
  
  func renderPreviousFrame() {
    frame -= 1
    if(frame < 0) {
     frame = imageBuffers.count - 1
    }
    renderFrame()
  }
  
  func renderFrame() {
    frame %= imageBuffers.count
    counter.update(String(frame))
    let imageBuffer = imageBuffers[frame]
    let ciImage : CIImage = CIImage(cvPixelBuffer: imageBuffer)
    let context:CIContext = CIContext.init(options: nil)
    let cgImage:CGImage = context.createCGImage(ciImage, from: ciImage.extent)!
    let previewLayer = CALayer()
    let width = view.bounds.width
    let height = width * aspectRatioHeight/aspectRatioWidth
    let top = (view.bounds.height - height)/2
    previewLayer.frame = CGRect(x: 0, y: top, width: width, height: height)
    previewLayer.contents = cgImage
    videoPreview.layer.addSublayer(previewLayer)
    setUpLayers()
    predict(pixelBuffer: imageBuffer)
  }
  
  // MARK: - UI stuff
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    resizePreviewLayer()
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  func resizePreviewLayer() {
    if (videoCapture != nil) {
      videoCapture.previewLayer?.frame = videoPreview.bounds
    }
  }
  
  // MARK: - Doing inference
  
  func predict(image: UIImage) {
    if let pixelBuffer = image.pixelBuffer(width: YOLO.inputWidth, height: YOLO.inputHeight) {
      predict(pixelBuffer: pixelBuffer)
    }
  }
  
  func predict(pixelBuffer: CVPixelBuffer) {
    // Measure how long it takes to predict a single video frame.
    let startTime = CACurrentMediaTime()
    
    // Resize the input with Core Image to 416x416.
    guard let resizedPixelBuffer = resizedPixelBuffer else { return }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let sx = CGFloat(YOLO.inputWidth) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    let sy = CGFloat(YOLO.inputHeight) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
    let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
    let scaledImage = ciImage.transformed(by: scaleTransform)
    ciContext.render(scaledImage, to: resizedPixelBuffer)
    
    // This is an alternative way to resize the image (using vImage):
    //if let resizedPixelBuffer = resizePixelBuffer(pixelBuffer,
    //                                              width: YOLO.inputWidth,
    //                                              height: YOLO.inputHeight)
    
    // Resize the input to 416x416 and give it to our model.
    if let boundingBoxes = try? yolo.predict(image: resizedPixelBuffer) {
      let elapsed = CACurrentMediaTime() - startTime
      showOnMainThread(boundingBoxes, elapsed)
    }
  }
  
  func predictUsingVision(pixelBuffer: CVPixelBuffer) {
    // Measure how long it takes to predict a single video frame. Note that
    // predict() can be called on the next frame while the previous one is
    // still being processed. Hence the need to queue up the start times.
    startTimes.append(CACurrentMediaTime())
    
    // Vision will automatically resize the input image.
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
    try? handler.perform([request])
  }
  
  func visionRequestDidComplete(request: VNRequest, error: Error?) {
    if let observations = request.results as? [VNCoreMLFeatureValueObservation],
      let features = observations.first?.featureValue.multiArrayValue {
      
      let boundingBoxes = yolo.computeBoundingBoxes(features: [features, features, features])
      let elapsed = CACurrentMediaTime() - startTimes.remove(at: 0)
      showOnMainThread(boundingBoxes, elapsed)
    }
  }
  
  func showOnMainThread(_ boundingBoxes: [YOLO.Prediction], _ elapsed: CFTimeInterval) {
    DispatchQueue.main.async {
      // For debugging, to make sure the resized CVPixelBuffer is correct.
      //var debugImage: CGImage?
      //VTCreateCGImageFromCVPixelBuffer(resizedPixelBuffer, nil, &debugImage)
      //self.debugImageView.image = UIImage(cgImage: debugImage!)
      
      var dets :[[Double]] = []
      for bb in boundingBoxes {
        dets.append([Double(bb.rect.origin.x),
                     Double(bb.rect.origin.y),
                     Double(bb.rect.origin.x + bb.rect.size.width),
                     Double(bb.rect.origin.y + bb.rect.size.height),
                     Double(bb.score)])
      }
//      print("dets:")
//      print(dets)
      let tracks :[[Double]] = self.tracker.update(dets: dets)
//      print("tracks:")
//      print(tracks)
//      print("-----")
//      let tracks:[[Double]] = []
      
      self.show(predictions: boundingBoxes, tracks: tracks)
      
      let fps = self.measureFPS()
      self.timeLabel.text = String(format: "Elapsed %.5f seconds - %.2f FPS", elapsed, fps)
      
      self.semaphore.signal()
    }
  }
  
  func measureFPS() -> Double {
    // Measure how many frames were actually delivered per second.
    framesDone += 1
    let frameCapturingElapsed = CACurrentMediaTime() - frameCapturingStartTime
    let currentFPSDelivered = Double(framesDone) / frameCapturingElapsed
    if frameCapturingElapsed > 1 {
      framesDone = 0
      frameCapturingStartTime = CACurrentMediaTime()
    }
    return currentFPSDelivered
  }
  
  func show(predictions: [YOLO.Prediction], tracks: [[Double]]) {
    // The predicted bounding box is in the coordinate space of the input
    // image, which is a square image of 416x416 pixels. We want to show it
    // on the video preview, which is as wide as the screen and has a 4:3
    // aspect ratio. The video preview also may be letterboxed at the top
    // and bottom.
    let width = view.bounds.width
    let height = width * aspectRatioHeight / aspectRatioWidth
    let scaleX = width / CGFloat(YOLO.inputWidth)
    let scaleY = height / CGFloat(YOLO.inputHeight)
    let top = (view.bounds.height - height) / 2
    
    for i in 0..<boundingBoxes.count {
      if i < predictions.count {
        let prediction = predictions[i]
        
        // Translate and scale the rectangle to our own coordinate system.
        var rect = prediction.rect
        rect.origin.x *= scaleX
        rect.origin.y *= scaleY
        rect.origin.y += top
        rect.size.width *= scaleX
        rect.size.height *= scaleY
        
        // Show the bounding box.
        let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
        let color = colors[prediction.classIndex]
        boundingBoxes[i].show(frame: rect, label: label, color: color)
      } else {
        boundingBoxes[i].hide()
      }
    }
    
    let previous = memory
    memory = [:]
    
    for i in 0..<trackBoxes.count {
      if i < tracks.count {
        let track = tracks[i]
        let index = Int(track[4])
        let x = CGFloat(track[0]) * scaleX
        let y = (CGFloat(track[1]) * scaleY) + top
        let width = CGFloat(track[2] - track[0]) * scaleX
        let height = CGFloat(track[3] - track[1]) * scaleY
        let rect:CGRect = CGRect(x: x, y: y, width: width, height: height)
        let label = String(format: "%.1f", track[4])
        let color = colors[Int(track[4]) % 80]
        trackBoxes[i].show(frame: rect, label: label, color: color, isTrack: true)
        memory[index] = [x, y, width, height]
        
        if(previous[index] != nil) {
          let p = previous[index]!
          let x2 = p[0]
          let y2 = p[1]
          let width2 = p[2]
          let height2 = p[3]
          let A = CGPoint(x: x + width/2, y: y + height/2)
          let B = CGPoint(x: x2 + width2/2, y: y2 + height2/2)
          let C = line.from
          let D = line.to
          
          if intersect(A,B,C,D) {
            counter.increment()
          }
        }
        
      } else {
        trackBoxes[i].hide()
      }
    }
  }
  
  func ccw(_ A:CGPoint,_ B:CGPoint,_ C:CGPoint) -> Bool {
    return ((C.y-A.y) * (B.x-A.x)) > ((B.y-A.y) * (C.x-A.x))
  }

  // Return true if line segments AB and CD intersect
  func intersect(_ A:CGPoint, _ B:CGPoint, _ C:CGPoint, _ D:CGPoint) -> Bool {
    return (ccw(A,C,D) != ccw(B,C,D)) && (ccw(A,B,C) != ccw(A,B,D))
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//    if let touch = touches.first {
//      let point = touch.location(in: self.videoPreview)
//      if(point.x > view.bounds.width/2) {
//        renderNextFrame()
//      } else {
//        renderPreviousFrame()
//      }
//    }
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let touch = touches.first {
      let point = touch.location(in: self.videoPreview)
      
      if(line.fromDotLayer.path!.contains(point)) {
        line.from = point
        line.draw()
        counter.reset()
      }
      
      if(line.toDotLayer.path!.contains(point)) {
        line.to = point
        line.draw()
        counter.reset()
      }
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
  }
}

extension ViewController: VideoCaptureDelegate {
  func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
    // For debugging.
    //predict(image: UIImage(named: "dog416")!); return
    
    semaphore.wait()
    
    if let pixelBuffer = pixelBuffer {
      // For better throughput, perform the prediction on a background queue
      // instead of on the VideoCapture queue. We use the semaphore to block
      // the capture queue and drop frames when Core ML can't keep up.
      DispatchQueue.global().async {
        self.predict(pixelBuffer: pixelBuffer)
        //self.predictUsingVision(pixelBuffer: pixelBuffer)
      }
    }
  }
}
