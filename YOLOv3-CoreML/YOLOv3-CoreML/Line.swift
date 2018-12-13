import Foundation
import UIKit

class Line {
  public var from:CGPoint
  public var to:CGPoint
  
  let lineLayer: CAShapeLayer
  public let fromDotLayer: CAShapeLayer
  public let toDotLayer: CAShapeLayer
  
  init() {
    from = CGPoint(x: 0, y: 0)
    to = CGPoint(x: 0, y: 0)
    
    lineLayer = CAShapeLayer()
    lineLayer.strokeColor = UIColor.red.cgColor
    lineLayer.lineWidth = 4.0
    
    fromDotLayer = CAShapeLayer()
    fromDotLayer.fillColor = UIColor.yellow.cgColor

    toDotLayer = CAShapeLayer()
    toDotLayer.fillColor = UIColor.yellow.cgColor
  }
  
  func show(from: CGPoint, to: CGPoint) {
    self.from = from
    self.to = to
    draw()
  }
  
  func draw() {
    let linePath = UIBezierPath()
    linePath.move(to: from)
    linePath.addLine(to: to)
    lineLayer.path = linePath.cgPath
    
    let fromCirclePath = UIBezierPath(arcCenter: from, radius: CGFloat(20), startAngle: CGFloat(0), endAngle:CGFloat(Double.pi * 2), clockwise: true)
    fromDotLayer.path = fromCirclePath.cgPath
    
    let toCirclePath = UIBezierPath(arcCenter: to, radius: CGFloat(20), startAngle: CGFloat(0), endAngle:CGFloat(Double.pi * 2), clockwise: true)
    toDotLayer.path = toCirclePath.cgPath
  }
  
  func addToLayer(_ parent: CALayer) {
    parent.addSublayer(lineLayer)
    parent.addSublayer(fromDotLayer)
    parent.addSublayer(toDotLayer)
  }
  
}
