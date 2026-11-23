import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/sonar/sonar_update_io.dart';

void main() {
  late Directory temporary;
  late File file;
  late HttpServer server;
  late Dio dio;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('sonar-update-test-');
    file = File('${temporary.path}/setup.exe');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio(BaseOptions(validateStatus: (_) => true));
  });
  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
    await temporary.delete(recursive: true);
  });

  Future<void> download({String? digest}) => downloadSonarUpdate(
    dio: dio,
    url: 'http://127.0.0.1:${server.port}/setup.exe',
    file: file,
    size: 6,
    digest: digest,
  );

  test('resumes an interrupted response without promoting the partial file', () async {
    var requests = 0;
    server.listen((request) async {
      requests++;
      if (requests == 1) {
        request.response.add(utf8.encode('abc'));
      } else {
        expect(request.headers.value('range'), 'bytes=3-');
        request.response.statusCode = 206;
        request.response.headers.set('content-range', 'bytes 3-5/6');
        request.response.add(utf8.encode('def'));
      }
      await request.response.close();
    });
    await expectLater(download(), throwsA(isA<Exception>()));
    expect(await file.exists(), false);
    expect(await File('${file.path}.part').readAsString(), 'abc');
    await download();
    expect(await file.readAsString(), 'abcdef');
    expect(await File('${file.path}.part').exists(), false);
  });

  test('rejects a 206 response for the wrong byte range before appending', () async {
    await File('${file.path}.part').writeAsString('abc');
    server.listen((request) async {
      request.response.statusCode = 206;
      request.response.headers.set('content-range', 'bytes 0-2/6');
      request.response.add(utf8.encode('def'));
      await request.response.close();
    });
    await expectLater(download(), throwsA(isA<Exception>()));
    expect(await file.exists(), false);
    expect(await File('${file.path}.part').readAsString(), 'abc');
  });

  test('restarts cleanly when the server ignores the range header', () async {
    await File('${file.path}.part').writeAsString('bad');
    server.listen((request) async {
      request.response.add(utf8.encode('abcdef'));
      await request.response.close();
    });
    await download();
    expect(await file.readAsString(), 'abcdef');
  });

  for (final range in <String?>[null, 'bytes 3-5/7', 'bytes 3-6/6']) {
    test('rejects inconsistent Content-Range $range', () async {
      await File('${file.path}.part').writeAsString('abc');
      server.listen((request) async {
        request.response.statusCode = 206;
        if (range != null) request.response.headers.set('content-range', range);
        request.response.add(utf8.encode('def'));
        await request.response.close();
      });
      await expectLater(download(), throwsA(isA<Exception>()));
      expect(await file.exists(), false);
    });
  }

  test('discards an oversized partial file before downloading again', () async {
    await File('${file.path}.part').writeAsString('oversized');
    server.listen((request) async {
      expect(request.headers.value('range'), isNull);
      request.response.add(utf8.encode('abcdef'));
      await request.response.close();
    });
    await download();
    expect(await file.readAsString(), 'abcdef');
  });

  test('rejects corrupt content even when its size is correct', () async {
    server.listen((request) async {
      request.response.add(utf8.encode('abcdeg'));
      await request.response.close();
    });
    await expectLater(
      download(digest: 'sha256:bef57ec7f53a6d40beb640a780a639c83bc29ac8a9816f1fc6c5c6dcd93c4721'),
      throwsA(isA<Exception>()),
    );
    expect(await file.exists(), false);
    expect(await File('${file.path}.part').exists(), false);
  });

  test('verifies a complete partial file without requesting bytes again', () async {
    await File('${file.path}.part').writeAsString('abcdef');
    await download(digest: 'sha256:bef57ec7f53a6d40beb640a780a639c83bc29ac8a9816f1fc6c5c6dcd93c4721');
    expect(await file.readAsString(), 'abcdef');
  });

  test('stages an independent verified installer before the temp source can change', () async {
    await file.writeAsString('abcdef');
    final staged = await stageSonarWindowsUpdate(
      source: file,
      protectedDirectory: Directory('${temporary.path}${Platform.pathSeparator}protected'),
      size: 6,
      digest: 'sha256:bef57ec7f53a6d40beb640a780a639c83bc29ac8a9816f1fc6c5c6dcd93c4721',
    );
    await file.writeAsString('malware');
    expect(await staged.readAsString(), 'abcdef');
    expect(staged.path, startsWith('${temporary.path}${Platform.pathSeparator}protected${Platform.pathSeparator}'));
  });

  test('rejects a corrupt staged source and leaves no executable in the protected cache', () async {
    await file.writeAsString('abcdeg');
    final protected = Directory('${temporary.path}/protected');
    await expectLater(
      stageSonarWindowsUpdate(
        source: file,
        protectedDirectory: protected,
        size: 6,
        digest: 'sha256:bef57ec7f53a6d40beb640a780a639c83bc29ac8a9816f1fc6c5c6dcd93c4721',
      ),
      throwsA(isA<Exception>()),
    );
    expect(await protected.list(recursive: true).where((f) => f is File).toList(), isEmpty);
    expect(await file.readAsString(), 'abcdeg');
  });
}
