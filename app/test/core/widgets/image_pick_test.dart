import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/image_pick.dart';

ThemeData _themeFor(TargetPlatform platform) =>
    buildLightTheme().copyWith(platform: platform);

Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Future<void> Function(BuildContext) onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      theme: _themeFor(platform),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _selectCamera(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cámara'));
  await tester.pumpAndSettle();
}

Future<void> _selectGallery(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Galería'));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('camera denied ($platform)', () {
      testWidgets(
        'shows how to enable camera access after permission is denied',
        (tester) async {
          await _withPlatform(platform, () async {
            String? path;
            var picked = false;
            await _pumpLauncher(
              tester,
              platform: platform,
              onOpen: (context) async {
                path = await pickImagePath(
                  context,
                  requestCameraPermission: () async => PermissionStatus.denied,
                  pickImage:
                      ({
                        required ImageSource source,
                        double? maxWidth,
                        int? imageQuality,
                      }) async {
                        picked = true;
                        return null;
                      },
                );
              },
            );

            await _selectCamera(tester);

            expect(find.text('Se necesita acceso a la cámara'), findsOneWidget);
            expect(
              find.text(
                'Readendar necesita acceso a la cámara para hacer una foto. '
                'Puedes activarlo en Ajustes.',
              ),
              findsOneWidget,
            );
            expect(find.text('Abrir ajustes'), findsOneWidget);
            expect(picked, isFalse);
            expect(path, isNull);
          });
        },
      );

      testWidgets(
        'Open Settings opens device settings when camera is denied',
        (tester) async {
          await _withPlatform(platform, () async {
            var openedSettings = false;
            await _pumpLauncher(
              tester,
              platform: platform,
              onOpen: (context) async {
                await pickImagePath(
                  context,
                  requestCameraPermission: () async =>
                      PermissionStatus.permanentlyDenied,
                  openSettings: () async {
                    openedSettings = true;
                    return true;
                  },
                  pickImage:
                      ({
                        required ImageSource source,
                        double? maxWidth,
                        int? imageQuality,
                      }) async => null,
                );
              },
            );

            await _selectCamera(tester);
            await tester.tap(find.text('Abrir ajustes'));
            await tester.pumpAndSettle();

            expect(openedSettings, isTrue);
            expect(find.text('Se necesita acceso a la cámara'), findsNothing);
          });
        },
      );

      testWidgets('cancel leaves settings closed when camera is denied', (
        tester,
      ) async {
        await _withPlatform(platform, () async {
          var openedSettings = false;
          await _pumpLauncher(
            tester,
            platform: platform,
            onOpen: (context) async {
              await pickImagePath(
                context,
                requestCameraPermission: () async => PermissionStatus.denied,
                openSettings: () async {
                  openedSettings = true;
                  return true;
                },
                pickImage:
                    ({
                      required ImageSource source,
                      double? maxWidth,
                      int? imageQuality,
                    }) async => null,
              );
            },
          );

          await _selectCamera(tester);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();

          expect(openedSettings, isFalse);
          expect(find.text('Se necesita acceso a la cámara'), findsNothing);
        });
      });

      testWidgets(
        'picker camera_access_denied still shows the enable-permission message',
        (tester) async {
          await _withPlatform(platform, () async {
            await _pumpLauncher(
              tester,
              platform: platform,
              onOpen: (context) async {
                await pickImagePath(
                  context,
                  requestCameraPermission: () async => PermissionStatus.granted,
                  pickImage:
                      ({
                        required ImageSource source,
                        double? maxWidth,
                        int? imageQuality,
                      }) async {
                        throw PlatformException(code: 'camera_access_denied');
                      },
                );
              },
            );

            await _selectCamera(tester);

            expect(find.text('Se necesita acceso a la cámara'), findsOneWidget);
            expect(
              find.text(
                'Readendar necesita acceso a la cámara para hacer una foto. '
                'Puedes activarlo en Ajustes.',
              ),
              findsOneWidget,
            );
          });
        },
      );

      testWidgets(
        'disabled in Settings (permanentlyDenied) shows how to enable camera',
        (tester) async {
          await _withPlatform(platform, () async {
            var picked = false;
            await _pumpLauncher(
              tester,
              platform: platform,
              onOpen: (context) async {
                await pickImagePath(
                  context,
                  requestCameraPermission: () async =>
                      PermissionStatus.permanentlyDenied,
                  pickImage:
                      ({
                        required ImageSource source,
                        double? maxWidth,
                        int? imageQuality,
                      }) async {
                        picked = true;
                        return null;
                      },
                );
              },
            );

            await _selectCamera(tester);

            expect(find.text('Se necesita acceso a la cámara'), findsOneWidget);
            expect(
              find.text(
                'Readendar necesita acceso a la cámara para hacer una foto. '
                'Puedes activarlo en Ajustes.',
              ),
              findsOneWidget,
            );
            expect(find.text('Abrir ajustes'), findsOneWidget);
            expect(picked, isFalse);
          });
        },
      );

      testWidgets(
        'restricted camera access still shows the enable-permission message',
        (tester) async {
          await _withPlatform(platform, () async {
            await _pumpLauncher(
              tester,
              platform: platform,
              onOpen: (context) async {
                await pickImagePath(
                  context,
                  requestCameraPermission: () async =>
                      PermissionStatus.restricted,
                  pickImage:
                      ({
                        required ImageSource source,
                        double? maxWidth,
                        int? imageQuality,
                      }) async => null,
                );
              },
            );

            await _selectCamera(tester);

            expect(find.text('Se necesita acceso a la cámara'), findsOneWidget);
            expect(
              find.text(
                'Readendar necesita acceso a la cámara para hacer una foto. '
                'Puedes activarlo en Ajustes.',
              ),
              findsOneWidget,
            );
          });
        },
      );

      testWidgets(
        'permission request failure still shows the enable-permission message',
        (tester) async {
          await _withPlatform(platform, () async {
            var picked = false;
            await _pumpLauncher(
              tester,
              platform: platform,
              onOpen: (context) async {
                await pickImagePath(
                  context,
                  requestCameraPermission: () async {
                    throw PlatformException(
                      code: 'PermissionHandler.PermissionManager',
                      message: 'Unable to detect current Android Activity.',
                    );
                  },
                  pickImage:
                      ({
                        required ImageSource source,
                        double? maxWidth,
                        int? imageQuality,
                      }) async {
                        picked = true;
                        return null;
                      },
                );
              },
            );

            await _selectCamera(tester);

            expect(find.text('Se necesita acceso a la cámara'), findsOneWidget);
            expect(
              find.text(
                'Readendar necesita acceso a la cámara para hacer una foto. '
                'Puedes activarlo en Ajustes.',
              ),
              findsOneWidget,
            );
            expect(picked, isFalse);
          });
        },
      );

      testWidgets(
        'picker no_available_camera still shows the enable-permission message',
        (tester) async {
          await _withPlatform(platform, () async {
            await _pumpLauncher(
              tester,
              platform: platform,
              onOpen: (context) async {
                await pickImagePath(
                  context,
                  requestCameraPermission: () async => PermissionStatus.granted,
                  pickImage:
                      ({
                        required ImageSource source,
                        double? maxWidth,
                        int? imageQuality,
                      }) async {
                        throw PlatformException(code: 'no_available_camera');
                      },
                );
              },
            );

            await _selectCamera(tester);

            expect(find.text('Se necesita acceso a la cámara'), findsOneWidget);
            expect(
              find.text(
                'Readendar necesita acceso a la cámara para hacer una foto. '
                'Puedes activarlo en Ajustes.',
              ),
              findsOneWidget,
            );
          });
        },
      );
    });
  }

  testWidgets('granted camera permission proceeds to the picker', (
    tester,
  ) async {
    await _withPlatform(TargetPlatform.android, () async {
      String? path;
      ImageSource? usedSource;
      await _pumpLauncher(
        tester,
        platform: TargetPlatform.android,
        onOpen: (context) async {
          path = await pickImagePath(
            context,
            requestCameraPermission: () async => PermissionStatus.granted,
            pickImage:
                ({
                  required ImageSource source,
                  double? maxWidth,
                  int? imageQuality,
                }) async {
                  usedSource = source;
                  return XFile('/tmp/cover.jpg');
                },
          );
        },
      );

      await _selectCamera(tester);

      expect(find.text('Se necesita acceso a la cámara'), findsNothing);
      expect(usedSource, ImageSource.camera);
      expect(path, '/tmp/cover.jpg');
    });
  });

  testWidgets('fixed camera source skips the source sheet', (tester) async {
    await _withPlatform(TargetPlatform.android, () async {
      ImageSource? usedSource;
      await _pumpLauncher(
        tester,
        platform: TargetPlatform.android,
        onOpen: (context) async {
          await pickImagePath(
            context,
            source: ImageSource.camera,
            requestCameraPermission: () async => PermissionStatus.granted,
            pickImage:
                ({
                  required ImageSource source,
                  double? maxWidth,
                  int? imageQuality,
                }) async {
                  usedSource = source;
                  return XFile('/tmp/shelf.jpg');
                },
          );
        },
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Cámara'), findsNothing);
      expect(find.text('Galería'), findsNothing);
      expect(usedSource, ImageSource.camera);
    });
  });

  testWidgets('gallery opens the native picker without a settings modal', (
    tester,
  ) async {
    await _withPlatform(TargetPlatform.android, () async {
      String? path;
      ImageSource? usedSource;
      await _pumpLauncher(
        tester,
        platform: TargetPlatform.android,
        onOpen: (context) async {
          path = await pickImagePath(
            context,
            pickImage:
                ({
                  required ImageSource source,
                  double? maxWidth,
                  int? imageQuality,
                }) async {
                  usedSource = source;
                  return XFile('/tmp/shelf.jpg');
                },
          );
        },
      );

      await _selectGallery(tester);

      expect(find.text('Se necesita acceso a las fotos'), findsNothing);
      expect(usedSource, ImageSource.gallery);
      expect(path, '/tmp/shelf.jpg');
    });
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('gallery denied ($platform)', () {
      testWidgets(
        'picker photo_access_denied shows how to enable photos in Settings',
        (tester) async {
          await _withPlatform(platform, () async {
            await _pumpLauncher(
              tester,
              platform: platform,
              onOpen: (context) async {
                await pickImagePath(
                  context,
                  pickImage:
                      ({
                        required ImageSource source,
                        double? maxWidth,
                        int? imageQuality,
                      }) async {
                        throw PlatformException(code: 'photo_access_denied');
                      },
                );
              },
            );

            await _selectGallery(tester);

            expect(find.text('Se necesita acceso a las fotos'), findsOneWidget);
            expect(find.text('Abrir ajustes'), findsOneWidget);
          });
        },
      );

      testWidgets(
        'Open Settings opens device settings when photos are denied',
        (tester) async {
          await _withPlatform(platform, () async {
            var openedSettings = false;
            await _pumpLauncher(
              tester,
              platform: platform,
              onOpen: (context) async {
                await pickImagePath(
                  context,
                  openSettings: () async {
                    openedSettings = true;
                    return true;
                  },
                  pickImage:
                      ({
                        required ImageSource source,
                        double? maxWidth,
                        int? imageQuality,
                      }) async {
                        throw PlatformException(code: 'photo_access_denied');
                      },
                );
              },
            );

            await _selectGallery(tester);
            await tester.tap(find.text('Abrir ajustes'));
            await tester.pumpAndSettle();

            expect(openedSettings, isTrue);
            expect(find.text('Se necesita acceso a las fotos'), findsNothing);
          });
        },
      );
    });
  }
}
