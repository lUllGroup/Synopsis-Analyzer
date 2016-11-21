
#Synopsis Analyzer/Transcoder

![alt tag](https://dl.dropboxusercontent.com/u/42612525/SynopsisRTF/MainUI.png)


###Overview

Synopsis is video analysis and transcoding tool, as well as a metadata format for embeddeding advanced analyzed metadata within .MOV and (in testing) .MP4 video files. 

This repository hosts a Synopsis Multimedia Analyser and Transcoder implementation written for Mac OS X.

Synopsis can analysize video and embed the following metadata:

* Dominant Color and Histograms for every frame, and globally for color similarity and sorting,
* Perceptual hashing for perceptual similarity searching / sorting
* Visual Saliency (areas of visual interest)
* Motion amount, direction, and smoothness for every frame, and globally, for similarity and sorting.
* Automatic feature tracking 

###Workflow Opporunities:

**Archival**: 
* Analyze your media archive, optionally transcoding to an appropriate archival video format like H.264.
* Run spotlight queries locally by hand, or programatically to find media based on analyzed features.
* Export analyzed metadata to your SQL database, to run queries on your own database schema on the web.

**Design & Branding**:
* Analyze content and optionally transcode to an appropriate playback video format like ProRes, MotionJpeg or Apple Intermediate.
* Develop procedural designs and templates to add logos, text and graphics to content while maintaining the focus (saliency) of the original image.
* Develop motion graphics and transitions that are aware of the underlying content.

**Editing**:
* Analyze content and optionally transcode to an appropriate playback video format like ProRes, MotionJpeg or Apple Intermediate.
* Search and filter clips based on dominant color, motion, and histogram similarity.
* Develop software and rules to procedurally edit video based on the underlying content.

**Performance & VJing**:
* Analyze content and optionally transcode to an appropriate playback video format like ProRes, MotionJpeg or Apple Intermediate and eventually HAP.
* Automatic clip filtering based on your currently playing content, color palette and motion.
* Sort clips by motion, color, features, content, style.
* Video effects that follow content, choose their color scheme, and react to the clips you play without slowing down your performance by running computationally expensive and slow analysis in realtime.

###Extending Features:

Synopsis Analysis is plugin based, allowing developers to easily extend and experiment analyzing video and caching results for future use.

###In Development:

* Per Frame Image Description via Inception (via Tensorflow)
* Global Image Description via Inception (via Tensorflow)
* Per Frame Image Style Description (via Tensorflow)
* Global Image Style Description (via Tensorflow)

See the DesignDiscussion wiki for more information about possible modules and direction of development.

## Development Notes

Tensorflow 0.11 compiled with cuda 8.0 via XCode 7.3 command line tools, due to Cuda 8.0 SDK / Clang incompatibility.

sudo xcode-select --switch /Library/Developer/CommandLineTools

bazel build -c opt --copt=-mavx --config=cuda //tensorflow/tools/pip_package:build_pip_package

Tensorflow libtensorflow_cc.so compiled with

ALL OPTS but deadlocks:
bazel build -c opt --copt=-mavx --cxxopt=-fno-exceptions --cxxopt=--std=c++11 --cxxopt=-DNDEBUG --cxxopt=-DNOTFDBG --cxxopt=-O2 --cxxopt=-DUSE_GEMM_FOR_CONV --cxxopt=-D__ANDROID_TYPES_SLIM__ --cxxopt=-DTF_LEAN_BINARY --cxxopt=-D__thread=  //tensorflow:libtensorflow_cc.so

DOES NOT DEADLOCK:
bazel build -c opt --copt=-mavx --cxxopt=-fno-exceptions --cxxopt=--std=c++11 --cxxopt=-DNDEBUG --cxxopt=-DNOTFDBG --cxxopt=-O2 --cxxopt=-DUSE_GEMM_FOR_CONV //tensorflow:libtensorflow_cc.so
Build useful tools

bazel build tensorflow/python/tools:optimize_for_inference

build tensorflow/tools/quantization/quantize_graph

bazel-bin/tensorflow/python/tools/optimize_for_inference --input=/Users/vade/Documents/Repositories/Synopsis/Synopsis/Synopsis/TensorFlowAnalyzer/models/inception2015/tensorflow_inception_graph.pb --output=/Users/vade/Documents/Repositories/Synopsis/Synopsis/Synopsis/TensorFlowAnalyzer/models/inception2015/tensorflow_inception_graph_optimized.pb --input_names=Mul --output_names=softmax,pool_3 

bazel-bin/tensorflow/tools/quantization/quantize_graph --input=/Users/vade/Documents/Repositories/Synopsis/Synopsis/Synopsis/TensorFlowAnalyzer/models/inception2015/tensorflow_inception_graph_optimized.pb --output=/Users/vade/Documents/Repositories/Synopsis/Synopsis/Synopsis/TensorFlowAnalyzer/models/inception2015/tensorflow_inception_graph_quantized.pb --output_node_names=softmax --mode=weights_rounded
