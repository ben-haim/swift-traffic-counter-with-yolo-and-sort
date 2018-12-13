// https://github.com/scikit-learn/scikit-learn/blob/master/sklearn/utils/linear_assignment_.py

class HungarianState {

  var C :[[Double]]
  var transposed :Bool
  var row_uncovered :[Bool]
  var col_uncovered :[Bool]
  var Z0_r :Int
  var Z0_c :Int
  var path :[[Int]]
  var marked :[[Int]]

  init(cost_matrix: [[Double]]) {
    // cost_matrix = np.atleast_2d(cost_matrix)

    // If there are more rows (n) than columns (m), then the algorithm
    // will not be able to work correctly. Therefore, we
    // transpose the cost function when needed. Just have to
    // remember to swap the result columns back later.
    let transposed = (cost_matrix[0].count < cost_matrix.count)
    if transposed {
      self.C = HungarianState.transpose(cost_matrix)
    } else {
      self.C = cost_matrix
    }
    self.transposed = transposed

    // At this point, m >= n.
    let n = self.C.count
    let m = self.C[0].count
    self.row_uncovered = Array(repeating: true, count: n)
    self.col_uncovered = Array(repeating: true, count: m)
    self.Z0_r = 0
    self.Z0_c = 0
    self.path = Array(repeating: [0,0], count: n+m)
    self.marked = Array(repeating: Array(repeating: 0, count: m), count: n)

    // print("Hungarian init:")
    // print("self.C: \(self.C)")
    // print("self.row_uncovered: \(self.row_uncovered)")
    // print("self.col_uncovered: \(self.col_uncovered)")
    // print("self.Z0_r: \(self.Z0_r)")
    // print("self.Z0_c: \(self.Z0_c)")
    // print("self.path: \(self.path)")
    // print("self.marked: \(self.marked)")
  }

  func _clear_covers() {
    // Clear all covered matrix cells
    self.row_uncovered = Array(repeating: true, count: self.row_uncovered.count)
    self.col_uncovered = Array(repeating: true, count: self.col_uncovered.count)
  }

  static func transpose(_ input: [[Double]]) -> [[Double]] {
    var output:[[Double]] = []
    var x = 0
    for row in input {
      var y = 0
      for column in row {
        if(x == 0) {
          output.append([column])
        } else {
          output[y].append(column)
        }
        y += 1
      }
      x += 1
    }
    return output
  }
         
}
