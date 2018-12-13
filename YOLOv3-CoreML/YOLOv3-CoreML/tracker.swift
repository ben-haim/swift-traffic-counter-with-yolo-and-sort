import Foundation
import Surge

class KalmanBoxTracker {
  // This class represents the internel state of individual tracked objects observed as bbox.

  static var count = 0

  var kf :KalmanFilter
  var time_since_update :Int
  var id :Int
  var history :[[Double]]
  var hits :Int
  var hit_streak :Int
  var age :Int
  
  init(bbox: [Double]) {
    // Initialises a tracker using initial bounding box.
    
    // define constant velocity model
    self.kf = KalmanFilter(dim_x:7, dim_z:4)
    self.kf.F = Surge.Matrix<Double>([[1,0,0,0,1,0,0],[0,1,0,0,0,1,0],[0,0,1,0,0,0,1],[0,0,0,1,0,0,0],[0,0,0,0,1,0,0],[0,0,0,0,0,1,0],[0,0,0,0,0,0,1]])
    self.kf.H = Surge.Matrix<Double>([[1,0,0,0,0,0,0],[0,1,0,0,0,0,0],[0,0,1,0,0,0,0],[0,0,0,1,0,0,0]])

    self.kf.R[2,2] *= 10.0
    self.kf.R[3,3] *= 10.0

    for i in 4..<self.kf.P.rows {
      self.kf.P[i,i] *= 1000.0 // give high uncertainty to the unobservable initial velocities
    }
    self.kf.P = Surge.mul(10.0, self.kf.P)
    // print("self.kf.P")
    // print(self.kf.P)

    self.kf.Q[self.kf.Q.rows - 1, self.kf.Q.columns - 1] *= 0.01
    for i in 4..<self.kf.Q.rows {
      self.kf.Q[i,i] *= 0.01
    }
    // print("self.kf.Q")
    // print(self.kf.Q)

    self.time_since_update = 0
    self.id = KalmanBoxTracker.count
    KalmanBoxTracker.count += 1
    self.history = []
    self.hits = 0
    self.hit_streak = 0
    self.age = 0 

    for(i,value) in convert_bbox_to_z(bbox).enumerated() {
      self.kf.x[i, 0] = value
    }
  }

  func update(bbox: [Double]) {
    // Updates the state vector with observed bbox.
    self.time_since_update = 0
    self.history = []
    self.hits += 1
    self.hit_streak += 1
    self.kf.update(Surge.Matrix<Double>([convert_bbox_to_z(bbox)]))
    // self.kf.trace()
  }

  func predict() -> [Double]{
    // Advances the state vector and returns the predicted bounding box estimate.
    if (self.kf.x[6,0]+self.kf.x[2,0]) <= 0.0 {
      self.kf.x[6,0] = 0.0
    }
    self.kf.predict()
    // self.kf.trace()
    self.age += 1
    if self.time_since_update > 0 {
      self.hit_streak = 0
    }
    self.time_since_update += 1
    self.history.append(convert_x_to_bbox(self.kf.x))
    return self.history.last!
  }

  func get_state() -> [Double] {
    // Returns the current bounding box estimate.
    return convert_x_to_bbox(self.kf.x)
  }

  func convert_bbox_to_z(_ bbox: [Double]) -> [Double] {
    // Takes a bounding box in the form [x1,y1,x2,y2] and returns z in the form
    // [x,y,s,r] where x,y is the centre of the box and s is the scale/area and r is
    // the aspect ratio
    let w = bbox[2]-bbox[0]
    let h = bbox[3]-bbox[1]
    let x = bbox[0]+w/2.0
    let y = bbox[1]+h/2.0
    let s = w*h // scale is just area
    let r = w/h
    return [x,y,s,r]
  }

  func convert_x_to_bbox(_ x: Surge.Matrix<Double>, score: Double? = nil) -> [Double] {
    // Takes a bounding box in the centre form [x,y,s,r] and returns it in the form
    // [x1,y1,x2,y2] where x1,y1 is the top left and x2,y2 is the bottom right

    let w = sqrt(x[2,0] * x[3,0])
    let h = x[2,0]/w

    // print("w: \(w)")
    // print("h: \(h)")

    if score == nil {
        return [
          x[0,0] - (w/2.0),
          x[1,0] - (h/2.0),
          x[0,0] + (w/2.0),
          x[1,0] + (h/2.0)
        ]
    } else {
      return [
        x[0,0] - (w/2.0),
        x[1,0] - (h/2.0),
        x[0,0] + (w/2.0),
        x[1,0] + (h/2.0),
        score!
      ]
    }
  }

}
