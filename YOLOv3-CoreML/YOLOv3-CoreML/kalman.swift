// https://github.com/rlabbe/filterpy/blob/master/filterpy/kalman/kalman_filter.py

import Foundation
import Surge

class KalmanFilter {
  
  var dim_x :Int
  var dim_z :Int
  var dim_u :Int
  
  var x :Surge.Matrix<Double>
  var P :Surge.Matrix<Double>
  var Q :Surge.Matrix<Double>
  var B :Surge.Matrix<Double>?
  var F :Surge.Matrix<Double>
  var H :Surge.Matrix<Double>
  var R :Surge.Matrix<Double>
  var _alpha_sq :Double
  var M :Surge.Matrix<Double>
  var z :Surge.Matrix<Double>
  
  var K :Surge.Matrix<Double>
  var y :Surge.Matrix<Double>
  var S :Surge.Matrix<Double>
  var SI :Surge.Matrix<Double>
  
  var _I :Surge.Matrix<Double>
  
  var x_prior :Surge.Matrix<Double>
  var P_prior :Surge.Matrix<Double>
  
  var x_post :Surge.Matrix<Double>
  var P_post :Surge.Matrix<Double>
  
  init(dim_x :Int , dim_z :Int , dim_u :Int = 0) {
    self.dim_x = dim_x
    self.dim_z = dim_z
    self.dim_u = dim_u
    
    self.x = KalmanFilter.getZeros(rows: dim_x, columns: 1)       // state
    self.P = KalmanFilter.getIdentity(dim: dim_x)                 // uncertainty covariance
    self.Q = KalmanFilter.getIdentity(dim: dim_x)                 // process uncertainty
    self.B = nil                                                  // control transition matrix
    self.F = KalmanFilter.getIdentity(dim: dim_x)                 // state transition matrix
    self.H = KalmanFilter.getZeros(rows: dim_x, columns: dim_x)   // Measurement function
    self.R = KalmanFilter.getIdentity(dim: dim_z)                 // state uncertainty
    self._alpha_sq = 1.0                                          // fading memory control
    self.M = KalmanFilter.getZeros(rows: dim_z, columns: dim_z)   // process-measurement cross correlation
    self.z = KalmanFilter.getZeros(rows: dim_z, columns: 1)
    
    // gain and residual are computed during the innovation step. We
    // save them so that in case you want to inspect them for various
    // purposes
    self.K = KalmanFilter.getZeros(rows: dim_x, columns: dim_z)  // kalman gain
    self.y = KalmanFilter.getZeros(rows: dim_z, columns: 1)
    self.S = KalmanFilter.getZeros(rows: dim_z, columns: dim_z)  // system uncertainty
    self.SI = KalmanFilter.getZeros(rows: dim_z, columns: dim_z) // inverse system uncertainty
    
    // identity matrix. Do not alter this.
    self._I = KalmanFilter.getIdentity(dim: dim_x)
    
    // these will always be a copy of x,P after predict() is called
    self.x_prior = self.x
    self.P_prior = self.P
    
    // these will always be a copy of x,P after update() is called
    self.x_post = self.x
    self.P_post = self.P
  }
  
  func trace() {
    print("-----")
    print("kf:")
    print("kf.x")
    print(self.x)
    print("kf.P")
    print(self.P)
    print("kf.S")
    print(self.S)
    // print("kf.SI")
    // print(self.SI)
    print("kf.K")
    print(self.K)
    print("-----")
  }
  
  func predict(u:[Double]? = nil) {
    // Predict next state (prior) using the Kalman filter state propagation equations.
    
    // x = Fx + Bu
    if (B != nil && u != nil) {
      // self.x = dot(F, self.x) + dot(B, u)
    } else {
      x = Surge.mul(F, x)
    }
    
    // P = FPF' + Q
    P = Surge.mul(_alpha_sq, Surge.mul(Surge.mul(F, P), Surge.transpose(F))) + Q
    
    // save prior
    x_prior = x
    P_prior = P
  }
  
  func update(_ z: Surge.Matrix<Double>) {
    let z = Surge.transpose(z)
    
    // print("z - dot(kf.H, kf.x):")
    // print(Surge.transpose(z) - Surge.mul(H, x))
    
    // y = z - Hx
    // error (residual) between measurement and prediction
    y = z  - Surge.mul(H, x)
    // print("self.y:")
    // print(self.y)
    
    // common subexpression for speed
    // print("P:")
    // print(P)
    // print("Surge.transpose(H)")
    // print(Surge.transpose(H))
    let PHT:Surge.Matrix<Double> = Surge.mul(P, Surge.transpose(H))
    // print("PHT:")
    // print(PHT)
    
    // S = HPH' + R
    // project system uncertainty into measurement space
    S = Surge.mul(H, PHT) + R
    SI = Surge.inv(S)
    // K = PH'inv(S)
    // map system uncertainty into kalman gain
    K = Surge.mul(PHT, SI)
    
    // x = x + Ky
    // predict new x with residual scaled by the kalman gain
    x = x + Surge.mul(K, y)
    
    // P = (I-KH)P(I-KH)' + KRK'
    // This is more numerically stable
    // and works for non-optimal K vs the equation
    // P = (I-KH)P usually seen in the literature.
    
    let I_KH:Surge.Matrix<Double> = _I - Surge.mul(K, H)
    P = Surge.mul(Surge.mul(I_KH, P), Surge.transpose(I_KH)) + Surge.mul(Surge.mul(K, R), Surge.transpose(K))
    
    // save measurement and posterior state
    self.z = z
    x_post = x
    P_post = P
  }
  
  static func getZeros(rows:Int, columns:Int) -> Surge.Matrix<Double> {
    return Surge.Matrix<Double>(rows: rows, columns: columns, repeatedValue: 0.0)
  }
  static func getIdentity(dim:Int) -> Surge.Matrix<Double> {
    var matrix :Surge.Matrix<Double> = Surge.Matrix<Double>(rows: dim, columns: dim, repeatedValue: 0.0)
    for i in 0..<dim {
      matrix[i,i] = 1.0
    }
    return matrix
  }
}

