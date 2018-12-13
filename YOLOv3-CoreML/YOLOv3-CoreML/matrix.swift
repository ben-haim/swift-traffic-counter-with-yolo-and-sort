// https://github.com/Hypercubesoft/HCKalmanFilter/blob/master/HCKalmanFilter/HCMatrixObject.swift
// https://medium.com/@michael.m/creating-a-matrix-class-in-swift-3-0-a7ae4fee23e1
// https://github.com/JadenGeller/Dimensional

class Matrix {

  private var rows: Int
  private var columns: Int
  var matrix: [[Double]]

  init(rows:Int, columns:Int) {
    self.rows = rows
    self.columns = columns
    self.matrix = Array(repeatElement(Array(repeatElement(0.0, count: columns)), count: rows))
  }

  static func getIdentity(dim :Int) -> [[Double]] {
    let identityMatrix = Matrix(rows: dim, columns: dim)
    for i in 0..<dim {
      for j in 0..<dim {
        if i == j {
          identityMatrix.matrix[i][j] = 1.0
        }
      }
    }
    return identityMatrix.matrix
  }

  static func getZeros(rows:Int, columns:Int) -> [[Double]] {
    let zerosMatrix = Matrix(rows: rows, columns: columns)
    return zerosMatrix.matrix
  }

}
