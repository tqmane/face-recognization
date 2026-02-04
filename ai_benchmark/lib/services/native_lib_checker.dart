import 'dart:io';

class NativeLibStatus {
  final bool available;
  final String expectedPath;
  final String message;

  const NativeLibStatus({
    required this.available,
    required this.expectedPath,
    required this.message,
  });
}

NativeLibStatus checkTfliteCpuNativeLibrary() {
  if (Platform.isAndroid || Platform.isIOS) {
    return const NativeLibStatus(
      available: true,
      expectedPath: '(bundled by platform)',
      message: 'OK',
    );
  }

  // Matches tflite_flutter's internal binding paths.
  if (Platform.isMacOS) {
    final bundleContentsDir = Directory(Platform.resolvedExecutable).parent.parent.path;
    final expectedLower =
      '$bundleContentsDir/resources/libtensorflowlite_c-mac.dylib';
    final expectedUpper =
      '$bundleContentsDir/Resources/libtensorflowlite_c-mac.dylib';
    final okLower = File(expectedLower).existsSync();
    final okUpper = File(expectedUpper).existsSync();
    final ok = okLower || okUpper;
    final expected = okLower
      ? expectedLower
      : (okUpper ? expectedUpper : expectedLower);
    return NativeLibStatus(
      available: ok,
      expectedPath: expected,
      message: ok
          ? 'OK'
          : 'macOSではTFLiteのdylibをアプリバンドルに追加する必要があります。',
    );
  }

  if (Platform.isLinux) {
    final expected =
        '${Directory(Platform.resolvedExecutable).parent.path}/blobs/libtensorflowlite_c-linux.so';
    final ok = File(expected).existsSync();
    return NativeLibStatus(
      available: ok,
      expectedPath: expected,
      message: ok
          ? 'OK'
          : 'LinuxではTFLiteの.soをblobs/に配置してCMakeでinstallする必要があります。',
    );
  }

  if (Platform.isWindows) {
    final expected =
        '${Directory(Platform.resolvedExecutable).parent.path}\\blobs\\libtensorflowlite_c-win.dll';
    final ok = File(expected).existsSync();
    return NativeLibStatus(
      available: ok,
      expectedPath: expected,
      message: ok
          ? 'OK'
          : 'WindowsではTFLiteの.dllをblobs/に配置してCMakeでinstallする必要があります。',
    );
  }

  return NativeLibStatus(
    available: false,
    expectedPath: '(unknown)',
    message: '未対応のプラットフォーム: ${Platform.operatingSystem}',
  );
}
