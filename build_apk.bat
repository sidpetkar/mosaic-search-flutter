@echo off
echo Building signed APK for Mosaic Search...
echo.

echo Cleaning previous builds...
flutter clean

echo Getting dependencies...
flutter pub get

echo Building signed APK...
flutter build apk --release

echo.
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo SUCCESS! Your signed APK has been created at:
    echo build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo You can now share this APK with your friends!
    echo File size:
    dir "build\app\outputs\flutter-apk\app-release.apk" | findstr "app-release.apk"
) else (
    echo ERROR: APK build failed. Please check the error messages above.
)

echo.
pause 