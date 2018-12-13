# Swift Real-time Traffic Counter

The purpose of this project is to use iPhone's camera and processing capabilities to count vehicles on a street or road on real-time.

<img src="output/vallvidrera.gif" width="350"> <img src="output/ronda.gif" width="350">

This repo was forked and modified from [hollance/YOLO-CoreML-MPSNNGraph](https://github.com/hollance/YOLO-CoreML-MPSNNGraph) and [Ma-Dan/YOLOv3-CoreML](https://github.com/Ma-Dan/YOLOv3-CoreML).

These are the changes I made:

1. Included [mattt/Surge](https://github.com/mattt/Surge) matrix library.
2. Migrated Hungarian algorithm from its [Python](https://github.com/scikit-learn/scikit-learn/blob/master/sklearn/utils/linear_assignment_.py) version.
3. Migrated Kalman Filter from its [Python](https://github.com/rlabbe/filterpy/blob/master/filterpy/kalman/kalman_filter.py) version.
4. Migrated SORT algorithm from its [Python](https://github.com/abewley/sort) version.
5. Used SORT algorithm to track detected objects trajectories.
6. Added an interactive line to define an edge.
7. Count trajectories that overpass the edge.

## Pending work

1. Improve accuracy on YOLO's object detection.
2. Complete SORT, Kalman Filter and Hungarian algorithm migration to Python.
3. Fix edge line on space (like new Apple's Measure app does)
4. Count different types of objects

## Quick Start

1. Extract YOLOv3 CoreML model in YOLOv3 CoreML model folder and copy to YOLOv3-CoreML/YOLOv3-CoreML folder.
2. Open the **xcodeproj** file in Xcode 9 and run it on a device with iOS 11 or better installed.

## About YOLO

YOLO is an object detection network. It can detect multiple objects in an image and puts bounding boxes around these objects. Read Matthijs Hollemans's [blog post](http://machinethink.net/blog/object-detection-with-yolo/) to learn more about how it works.

## About SORT

SORT is a simple online and realtime tracking algorithm for 2D multiple object tracking in video sequences. Check Alex Bewley's [SORT repository](https://github.com/abewley/sort) to learn how it works.

## About SURGE

Surge is a Swift library that uses the Accelerate framework to provide high-performance functions for matrix math, digital signal processing, and image manipulation. Check Mattt's [SURGE repository](https://github.com/mattt/Surge) to learn how it works.

## Citation

### YOLO :

    @article{redmon2016yolo9000,
      title={YOLO9000: Better, Faster, Stronger},
      author={Redmon, Joseph and Farhadi, Ali},
      journal={arXiv preprint arXiv:1612.08242},
      year={2016}
    }

### SORT :

    @inproceedings{Bewley2016_sort,
      author={Bewley, Alex and Ge, Zongyuan and Ott, Lionel and Ramos, Fabio and Upcroft, Ben},
      booktitle={2016 IEEE International Conference on Image Processing (ICIP)},
      title={Simple online and realtime tracking},
      year={2016},
      pages={3464-3468},
      keywords={Benchmark testing;Complexity theory;Detectors;Kalman filters;Target tracking;Visualization;Computer Vision;Data Association;Detection;Multiple Object Tracking},
      doi={10.1109/ICIP.2016.7533003}
    }

