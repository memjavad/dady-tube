import 'dart:ui';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dadytube/services/distance_protection_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mocktail/mocktail.dart';

class MockCameraController extends Mock implements CameraController {}

class MockFaceDetector extends Mock implements FaceDetector {}

class MockCameraImage extends Mock implements CameraImage {}

class MockPlane extends Mock implements Plane {}

class MockCameraDescription extends Mock implements CameraDescription {}

class MockFace extends Mock implements Face {}

class MockImageFormat extends Mock implements ImageFormat {}

class FakeInputImage extends Fake implements InputImage {}

void main() {
  late DistanceProtectionService service;
  late MockCameraController mockCameraController;
  late MockFaceDetector mockFaceDetector;
  late MockCameraImage mockImage;
  late MockPlane mockPlane;
  late MockCameraDescription mockCameraDescription;
  late MockImageFormat mockImageFormat;

  setUpAll(() {
    registerFallbackValue(FakeInputImage());
  });

  setUp(() {
    service = DistanceProtectionService();
    service.resetForTesting();

    mockCameraController = MockCameraController();
    mockFaceDetector = MockFaceDetector();
    mockImage = MockCameraImage();
    mockPlane = MockPlane();
    mockCameraDescription = MockCameraDescription();
    mockImageFormat = MockImageFormat();

    when(
      () => mockCameraController.description,
    ).thenReturn(mockCameraDescription);
    when(() => mockCameraDescription.sensorOrientation).thenReturn(90);

    when(() => mockPlane.bytes).thenReturn(Uint8List(4));
    when(() => mockPlane.bytesPerRow).thenReturn(4);
    when(() => mockImage.planes).thenReturn([mockPlane]);
    when(() => mockImage.width).thenReturn(100);
    when(() => mockImage.height).thenReturn(100);
    when(() => mockImage.format).thenReturn(mockImageFormat);
    when(() => mockImageFormat.raw).thenReturn(35); // 35 is NV21 format

    service.cameraControllerForTesting = mockCameraController;
    service.faceDetectorForTesting = mockFaceDetector;
  });

  test('processImage should not process if busy', () async {
    service.isBusyForTesting = true;

    await service.processImageForTesting(mockImage);

    verifyNever(() => mockFaceDetector.processImage(any()));
  });

  test('processImage should not process if recently processed', () async {
    service.lastProcessedTimestampForTesting =
        DateTime.now().millisecondsSinceEpoch;

    await service.processImageForTesting(mockImage);

    verifyNever(() => mockFaceDetector.processImage(any()));
  });

  test('processImage should not process if face detector is null', () async {
    service.faceDetectorForTesting = null;

    await service.processImageForTesting(mockImage);

    verifyNever(() => mockFaceDetector.processImage(any()));
  });

  group('face detection scenarios', () {
    test('emits no issues when no face detected', () async {
      when(
        () => mockFaceDetector.processImage(any()),
      ).thenAnswer((_) async => []);

      final futureTooClose = service.isTooCloseStream.first;
      final futureSlouching = service.isSlouchingStream.first;

      await service.processImageForTesting(mockImage);

      expect(await futureTooClose, false);
      expect(await futureSlouching, false);
    });

    test('emits isTooClose=true when face width ratio > 0.65', () async {
      final mockFace = MockFace();
      when(() => mockFace.boundingBox).thenReturn(
        const Rect.fromLTWH(0, 0, 70, 70),
      ); // ratio = 70/100 = 0.7 > 0.65
      when(() => mockFace.headEulerAngleX).thenReturn(0);

      when(
        () => mockFaceDetector.processImage(any()),
      ).thenAnswer((_) async => [mockFace]);

      final futureTooClose = service.isTooCloseStream.first;
      final futureSlouching = service.isSlouchingStream.first;

      await service.processImageForTesting(mockImage);

      expect(await futureTooClose, true);
      expect(await futureSlouching, false);
    });

    test('emits isSlouching=true when face top ratio > 0.65', () async {
      final mockFace = MockFace();
      when(() => mockFace.boundingBox).thenReturn(
        const Rect.fromLTWH(0, 70, 20, 20),
      ); // top ratio = 70/100 = 0.7 > 0.65
      when(() => mockFace.headEulerAngleX).thenReturn(0);

      when(
        () => mockFaceDetector.processImage(any()),
      ).thenAnswer((_) async => [mockFace]);

      final futureTooClose = service.isTooCloseStream.first;
      final futureSlouching = service.isSlouchingStream.first;

      await service.processImageForTesting(mockImage);

      expect(await futureTooClose, false);
      expect(await futureSlouching, true);
    });

    test('emits isSlouching=true when head tilt > 25', () async {
      final mockFace = MockFace();
      when(
        () => mockFace.boundingBox,
      ).thenReturn(const Rect.fromLTWH(0, 0, 20, 20));
      when(() => mockFace.headEulerAngleX).thenReturn(30); // tilt > 25

      when(
        () => mockFaceDetector.processImage(any()),
      ).thenAnswer((_) async => [mockFace]);

      final futureTooClose = service.isTooCloseStream.first;
      final futureSlouching = service.isSlouchingStream.first;

      await service.processImageForTesting(mockImage);

      expect(await futureTooClose, false);
      expect(await futureSlouching, true);
    });
  });
}
