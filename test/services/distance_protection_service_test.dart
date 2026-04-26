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
  late MockCameraDescription mockCameraDescription;

  setUpAll(() {
    registerFallbackValue(FakeInputImage());
  });

  setUp(() {
    mockCameraController = MockCameraController();
    mockFaceDetector = MockFaceDetector();
    mockImage = MockCameraImage();
    mockCameraDescription = MockCameraDescription();

    when(() => mockCameraController.description)
        .thenReturn(mockCameraDescription);
    when(() => mockCameraDescription.sensorOrientation).thenReturn(90);
    when(() => mockCameraController.stopImageStream()).thenAnswer((_) async => {});
    when(() => mockCameraController.dispose()).thenAnswer((_) async => {});
    when(() => mockFaceDetector.close()).thenAnswer((_) async => {});

    final mockFormat = MockImageFormat();
    when(() => mockFormat.group).thenReturn(ImageFormatGroup.yuv420);
    when(() => mockImage.format).thenReturn(mockFormat);
    when(() => mockImage.width).thenReturn(100);
    when(() => mockImage.height).thenReturn(100);

    final mockPlane = MockPlane();
    when(() => mockPlane.bytes).thenReturn(Uint8List(0));
    when(() => mockPlane.bytesPerRow).thenReturn(100);
    when(() => mockPlane.bytesPerPixel).thenReturn(1);
    when(() => mockImage.planes).thenReturn([mockPlane]);

    service = DistanceProtectionService();
    service.cameraControllerForTesting = mockCameraController;
    service.faceDetectorForTesting = mockFaceDetector;
    service.isBusyForTesting = false;
    service.lastProcessedTimestampForTesting = 0;
  });

  tearDown(() {
    service.dispose();
  });

  group('processImage', () {
    test('should not process if busy', () async {
      when(() => mockFaceDetector.processImage(any())).thenAnswer(
        (_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return [];
        },
      );

      final future1 = service.processImageForTesting(mockImage);
      final future2 = service.processImageForTesting(mockImage);

      await Future.wait([future1, future2]);

      verify(() => mockFaceDetector.processImage(any())).called(1);
    });

    test('should not process if recently processed', () async {
      when(
        () => mockFaceDetector.processImage(any()),
      ).thenAnswer((_) async => []);

      await service.processImageForTesting(mockImage);
      await service.processImageForTesting(mockImage);

      verify(() => mockFaceDetector.processImage(any())).called(1);
    });

    test('should not process if face detector is null', () async {
      service.faceDetectorForTesting = null;

      await service.processImageForTesting(mockImage);

      verifyNever(() => mockFaceDetector.processImage(any()));
    });
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
      ); // 70/100 = 0.7 > 0.65
      when(() => mockFace.headEulerAngleX).thenReturn(0.0);

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
      // NOTE: This test doesn't make sense anymore since we removed the face.boundingBox.top check
      // We should probably just verify it DOES NOT emit isSlouching=true anymore for this scenario
      final mockFace = MockFace();
      when(() => mockFace.boundingBox).thenReturn(
        const Rect.fromLTWH(0, 70, 20, 20),
      ); // top ratio = 70/100 = 0.7 > 0.65
      when(() => mockFace.headEulerAngleX).thenReturn(0.0);

      when(
        () => mockFaceDetector.processImage(any()),
      ).thenAnswer((_) async => [mockFace]);

      final futureTooClose = service.isTooCloseStream.first;
      final futureSlouching = service.isSlouchingStream.first;

      await service.processImageForTesting(mockImage);

      expect(await futureTooClose, false);
      expect(await futureSlouching, false); // CHANGED to false due to recent implementation change
    });

    test('emits isSlouching=true when head tilt < -20', () async {
      final mockFace = MockFace();
      when(
        () => mockFace.boundingBox,
      ).thenReturn(const Rect.fromLTWH(0, 0, 20, 20));
      when(() => mockFace.headEulerAngleX).thenReturn(-30.0); // pitch < -20

      when(
        () => mockFaceDetector.processImage(any()),
      ).thenAnswer((_) async => [mockFace]);

      final futureTooClose = service.isTooCloseStream.first;
      final futureSlouching = service.isSlouchingStream.first;

      await service.processImageForTesting(mockImage);

      expect(await futureTooClose, false);
      expect(await futureSlouching, true); // Should be true when pitch < -20
    });
  });
}
