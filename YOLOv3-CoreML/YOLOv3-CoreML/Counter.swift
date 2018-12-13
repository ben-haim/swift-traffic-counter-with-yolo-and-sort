import Foundation
import UIKit

class Counter {
  var count: Int = 0
  let textLayer: CATextLayer
  
  init() {
    textLayer = CATextLayer()
    textLayer.foregroundColor = UIColor.white.cgColor
    textLayer.backgroundColor = UIColor.black.cgColor
    textLayer.contentsScale = UIScreen.main.scale
    textLayer.fontSize = 30
    textLayer.font = UIFont(name: "Avenir", size: textLayer.fontSize)
    textLayer.alignmentMode = CATextLayerAlignmentMode.center
    
    let label = String(count)
    textLayer.string = label

    let attributes = [
      NSAttributedString.Key.font: textLayer.font as Any
    ]

    let textRect = label.boundingRect(with: CGSize(width: 400, height: 100), options: .truncatesLastVisibleLine, attributes: attributes, context: nil)
    let textSize = CGSize(width: textRect.width + 40, height: textRect.height)
    textLayer.frame = CGRect(origin: CGPoint(x: 0, y: 100), size: textSize)
  }
  
  func addToLayer(_ parent: CALayer) {
    parent.addSublayer(textLayer)
  }
  
  func increment() {
    count += 1
    update()
  }
  
  func reset() {
    count = 0
    update()
  }
  
  func update() {
    textLayer.string = String(count)
  }
  
  func update(_ label:String) {
    textLayer.string = label
  }
  
  
}
