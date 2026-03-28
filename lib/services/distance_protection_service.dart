import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

class DistanceProtectionService {
  static final DistanceProtectionService _instance = DistanceProtectionService._internal();
  factory DistanceProtectionService() => _instance;
  DistanceProtectionService._internal();

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isBusy = false;
  final _statusController = StreamController<bool>.broadcast();
  final _postureController = StreamController<bool>.broadcast();

  Stream<bool> get isTooCloseStream => _statusController.stream;
  Stream<bool> get isSlouchingStream => _postureController.stream;

  Future<void> initialize() async {
    if (_cameraController != null) return;

    // Check and request camera permission
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      debugPrint('Camera permission denied for distance protection');
      _statusController.add(false); // Reset if denied
      return;
    }

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // Optimized for Android/MLKit
    );

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // Needed for Posture (Head tilt)
        enableLandmarks: false,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    try {
      await _cameraController!.initialize();
      _cameraController!.startImageStream(_processImage);
    } catch (e) {
      debugPrint('Error initializing camera for distance protection: $e');
    }
  }

  Future<void> dispose() async {
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    await _faceDetector?.close();
    _cameraController = null;
    _faceDetector = null;
  }

  int _lastProcessedTimestamp = 0;
  bool _lastResult = false;
  int _consecutiveStatusCount = 0;

  Future<void> _processImage(CameraImage image) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Ultra-Light: Only process 1 frame every 1200ms (approx 0.8 FPS)
    // This dramatically reduces CPU pressure while remaining safe.
    if (_isBusy || _faceDetector == null || (now - _lastProcessedTimestamp < 1200)) return;
    
    _isBusy = true;
    _lastProcessedTimestamp = now;

    try {
      // Optimized conversion: Only convert if we are definitely going to process
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final sensorOrientation = _cameraController!.description.sensorOrientation;
      InputImageRotation rotation = InputImageRotation.rotation0deg;
      
      if (sensorOrientation == 90) rotation = InputImageRotation.rotation90deg;
      else if (sensorOrientation == 180) rotation = InputImageRotation.rotation180deg;
      else if (sensorOrientation == 270) rotation = InputImageRotation.rotation270deg;

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final faces = await _faceDetector!.processImage(inputImage);
      
      bool isTooClose = false;
      if (faces.isNotEmpty) {
        final face = faces.first;
        final imageSize = (rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg)
            ? image.height 
            : image.width;
        
        final faceWidthRatio = face.boundingBox.width / imageSize;
        isTooClose = faceWidthRatio > 0.65; // Slightly more lenient to reduce flickering

        // --- Posture Detection ---
        // 1. Slouching Detection (Face too low in frame)
        // Normalized Y coordinate of the face top. If > 0.65, face is too low.
        final faceTopRatio = face.boundingBox.top / (rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg ? image.width : image.height);
        
        // 2. Head Tilt Detection (Looking down)
        // eulerAngleX is the up/down tilt. Positive is looking down usually in MLKit.
        final headTilt = face.headEulerAngleX ?? 0;
        
        bool isSlouching = faceTopRatio > 0.65 || headTilt > 25;
        _postureController.add(isSlouching);
      } else {
        // No face detected, assume no posture issue for now to avoid false positives
        _postureController.add(false);
      }

      // Quick dispatch for status change
      _statusController.add(isTooClose);

    } catch (e) {
      debugPrint('Error processing face image: $e');
    }

    _isBusy = false;
  }
}
