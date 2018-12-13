class Sort {
  var max_age = 1
  var min_hits = 3
  var frame_count = 0
  var trackers: [KalmanBoxTracker] = []
  
  init() {}

  init(max_age:Int, min_hits:Int) {
    self.max_age = max_age
    self.min_hits = min_hits
  }

  func update(dets: [[Double]]) -> [[Double]] {
    self.frame_count += 1
    //print("Frame count: \(self.frame_count)")

    // get predicted locations from existing trackers.
    //print("# of trackers: \(trackers.count)")
    var trks:[[Double]] = Matrix.getZeros(rows: trackers.count, columns: 5)
    var to_del:[Int] = []
    var ret:[[Double]] = []

    //print("Tracker predict:")
    for(t,_) in trks.enumerated() {
      //print("\(t) - \(trk)")
      let pos :[Double] = trackers[t].predict()
      //print("pos: \(pos)")
      trks[t] = [pos[0], pos[1], pos[2], pos[3], 0.0]
      if(pos[0].isNaN || pos[1].isNaN || pos[2].isNaN || pos[3].isNaN) {
        to_del.append(t)
      }
    }
    //print("-------------------")
    // trks = np.ma.compress_rows(np.ma.masked_invalid(trks))
    // for t in reversed(to_del):
    //   self.trackers.pop(t)
    let (matched, unmatched_dets, unmatched_trks) = associate_detections_to_trackers(detections: dets, trackers: trks)
    
    // update matched trackers with assigned detections
    //print("Tracker update:")
    if(dets.count > 0) {
      for (t, trk) in trackers.enumerated() {
        if !(unmatched_trks.contains(t)) {
          let d = matched.first(where: {$0[1]==t})![0]
          //print(dets[d])
          trk.update(bbox: dets[d])
        }
      }
    }
    //print("---")
    // create and initialise new trackers for unmatched detections
    for i in unmatched_dets {
      let trk = KalmanBoxTracker(bbox: dets[i])
      self.trackers.append(trk)
    }

    var i = self.trackers.count
    for trk:KalmanBoxTracker in self.trackers.reversed() {
      var d = trk.get_state()
      //print("trk.get_state(): \(d)")
      if((trk.time_since_update < 1) && (trk.hit_streak >= self.min_hits || self.frame_count <= self.min_hits)) {
        d.append(Double(trk.id+1))
        ret.append(d) // +1 as MOT benchmark requires positive
      }
      i -= 1
      // remove dead tracklet
      //print("\(trk.time_since_update), \(self.max_age)")
      if trk.time_since_update > self.max_age {
        //print("remove")
        self.trackers.remove(at: i)
      }

    }

    if ret.count > 0 {
      return ret
    } else {
      return []
    }
  }

  func associate_detections_to_trackers(detections: [[Double]], trackers: [[Double]], iou_threshold: Double = 0.3) -> (matched: [[Int]], unmatched_dets: [Int], unmatched_trks: [Int]){
    // Assigns detections to tracked object (both represented as bounding boxes)
    // Returns 3 lists of matches, unmatched_detections and unmatched_trackers

    if(trackers.isEmpty || detections.isEmpty) {
      return ([], [Int](0..<detections.count),[])
    }
    var iou_matrix :[[Double]] = Matrix.getZeros(rows: detections.count, columns: trackers.count)
    
    for (d, det) in detections.enumerated() {
      for (t, trk) in trackers.enumerated() {
        iou_matrix[d][t] = iou(bb_test: det, bb_gt: trk)
      }
    }
    let matched_indices = linear_assignment(X: iou_matrix.map { $0.map { $0 * -1.0 } })
    // print("matched_indices:")
    // print(matched_indices)

    var unmatched_detections:[Int] = []
    for (d,_) in detections.enumerated() {
      if(!matched_indices.map{$0[0]}.contains(d)) {
        unmatched_detections.append(d)
      }
    }

    var unmatched_trackers:[Int] = []
    for (t,_) in trackers.enumerated() {
      if(!matched_indices.map{$0[1]}.contains(t)) {
        unmatched_trackers.append(t)
      }
    }

    // filter out matched with low IOU
    var matches :[[Int]] = []
    for m in matched_indices {
      if iou_matrix[m[0]][m[1]] < iou_threshold {
        unmatched_detections.append(m[0])
        unmatched_trackers.append(m[1])
      } else {
        matches.append(m)
      }
    }

    //print("matches:")
    //print(matches)
    //print("unmatched_detections:")
    //print(unmatched_detections)
    //print("unmatched_trackers:")
    //print(unmatched_trackers)

    return (matches, unmatched_detections, unmatched_trackers)
  }

  func linear_assignment(X:[[Double]]) -> [[Int]] {
    // Solve the linear assignment problem using the Hungarian algorithm.

    // print("X:")
    // print(X)
    let indices = hungarian(cost_matrix: X).sorted(by: {$0[0] < $1[0]})
    // print("indices:")
    // print(indices)

    // Re-force dtype to ints in case of empty list
    // indices = np.array(indices, dtype=int)

    // Make sure the array is 2D with 2 columns.
    // This is needed when dealing with an empty list
    // indices.shape = (-1, 2)

    return indices
  }

  func hungarian(cost_matrix: [[Double]]) -> [[Int]] {
    let state = HungarianState(cost_matrix: cost_matrix)
    var step : Int?

    // No need to bother with assignments if one of the dimensions
    // of the cost matrix is zero-length.
    if cost_matrix.count == 0 || cost_matrix[0].count == 0 {
      step = nil
    } else {
      step = 1
    }

    while step != nil {
      step = _next_step(step: step, state: state)
    }

    // print("state.marked:")
    // print(state.marked)

    // Look for the starred columns
    var results:[[Int]] = []
    for (x, row) in state.marked.enumerated() {
      for (y, col) in row.enumerated() {
        if col == 1 {
          if state.transposed {
            // We need to swap the columns because we originally
            // did a transpose on the input cost matrix.
            results.append([y, x])
          } else {
            results.append([x, y])
          }
        }
      }
    }

    // return results
    return results
  }

  func _next_step(step: Int?, state: HungarianState) -> Int? {
    switch step {
      case 1: return _step1(state)
      case 3: return _step3(state)
      case 4: return _step4(state)
      default: return nil
    }
  }

  func _step1(_ state: HungarianState) -> Int? {
    //print("_step1")
    var zeros :[(Int,Int)] = []

    // Step1: For each row of the matrix, find the smallest element and
    // subtract it from every element in its row.
    for (x, row) in state.C.enumerated() {
      let min = row.min()
      if min != nil {
        for (y,col) in row.enumerated() {
          state.C[x][y] = col - min!
          if(state.C[x][y] == 0.0) {
            zeros.append((x,y))
          }
        }
      }
    }

    // Step2: Find a zero (Z) in the resulting matrix. If there is no
    // starred zero in its row or column, star Z. Repeat for each element
    // in the matrix.
    for zero in zeros {
      let i = zero.0
      let j = zero.1
      if state.col_uncovered[j] && state.row_uncovered[i] {
        state.marked[i][j] = 1
        state.col_uncovered[j] = false
        state.row_uncovered[i] = false
      }
    }

    // print("marked: ")
    // print(state.marked)

    state._clear_covers()
    return 3
  }

  func _step3(_ state: HungarianState) -> Int? {
//    print("_step3")

    // Cover each column containing a starred zero. If n columns are covered,
    // the starred zeros describe a complete set of unique assignments.
    // In this case, Go to DONE, otherwise, Go to Step 4.

    for row in 0..<state.marked[0].count {
      for col in 0..<state.marked.count {
        if(state.marked[col][row] == 1) {
          state.col_uncovered[row] = false
          continue
        }
      }
    }

    let marked_sum = state.marked.flatMap{$0}.reduce(0, +)

    // print("col_uncovered:")
    // print(state.col_uncovered)

    // print("sum:")
    // print(marked_sum)

    if marked_sum < state.C.count {
      return 4
    } else {
      return nil
    }
  }

  func _step4(_ state: HungarianState) -> Int? {
    print("_step4")
    return nil
  }


  func iou(bb_test: [Double], bb_gt: [Double]) -> Double {
    //  Computes IUO between two bboxes in the form [x1,y1,x2,y2]

    let xx1 = max(bb_test[0], bb_gt[0])
    let yy1 = max(bb_test[1], bb_gt[1])
    let xx2 = min(bb_test[2], bb_gt[2])
    let yy2 = min(bb_test[3], bb_gt[3])
    let w = max(0.0, xx2 - xx1)
    let h = max(0.0, yy2 - yy1)
    let wh = w * h
    let o = wh / ((bb_test[2]-bb_test[0])*(bb_test[3]-bb_test[1])
      + (bb_gt[2]-bb_gt[0])*(bb_gt[3]-bb_gt[1]) - wh)
    return(o)
  }
}
