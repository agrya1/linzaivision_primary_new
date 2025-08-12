@echo off
echo Setting software rendering environment variables...
set FLUTTER_ENGINE_SWITCH_1=--enable-software-rendering
set FLUTTER_ENGINE_SWITCH_2=--disable-gpu
set FLUTTER_ENGINE_SWITCH_3=--disable-gpu-sandbox

echo Starting Flutter app with software rendering...
flutter run --debug

pause
