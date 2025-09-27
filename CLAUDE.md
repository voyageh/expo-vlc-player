# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Expo module that provides VLC player functionality for React Native applications. The module enables streaming video playback through the VLC media player library.

### Key Architecture

- **Cross-platform Expo Module**: Uses Expo Modules API for native bridge
- **Native iOS Implementation**: Swift-based (`ios/ExpoVlcPlayerModule.swift`, `ios/ExpoVlcPlayerView.swift`)
- **Native Android Implementation**: Kotlin-based (`android/.../ExpoVlcPlayerModule.kt`, `android/.../ExpoVlcPlayerView.kt`)
- **JavaScript Interface**: TypeScript definitions and React Native view component (`src/`)
- **Example App**: Demo application showing usage (`example/App.tsx`)

### Core Components

1. **ExpoVlcPlayerView**: Main React Native component for video playback
2. **Native Modules**: Platform-specific VLC integration (iOS Swift, Android Kotlin)
3. **Type Definitions**: Complete TypeScript interfaces in `src/ExpoVlcPlayer.types.ts`

## Development Commands

### Build and Development
```bash
# Build the module
npm run build

# Clean build artifacts
npm run clean

# Lint code
npm run lint

# Run tests
npm run test

# Prepare for publishing
npm run prepare
npm run prepublishOnly
```

### IDE Integration
```bash
# Open iOS project in Xcode
npm run open:ios

# Open Android project in Android Studio
npm run open:android
```

### Platform Support
- **Android**: Fully implemented with VLC Android SDK
- **iOS**: Fully implemented with VLCKit 4.0.0a10
- **Web**: Not supported (web-specific files removed)

## Module Configuration

- **expo-module.config.json**: Defines platform modules and their class names
- **Native Modules**:
  - iOS: `ExpoVlcPlayerModule`
  - Android: `expo.modules.vlcplayer.ExpoVlcPlayerModule`

## Key Types and Props

Main component props include:
- `url`: Stream URL (RTSP, HTTP, etc.)
- `paused`: Playback state control
- `options`: VLC player options array (automatically normalized across platforms)
- `videoAspectRatio`: Video aspect ratio setting
- `resizeMode`: Video resize behavior (`contain`, `cover`, `stretch`, `fill`, `original`)
- Event callbacks: `onLoad`, `onPlaying`, `onError`

Ref methods:
- `retry()`: Retry failed stream connection

## iOS Implementation Details

- **VLCKit Integration**: Uses VLCKit 4.0.0a10 via CocoaPods
- **Video Surface**: Custom `CAEAGLLayer`-based view for hardware acceleration
- **Thread Safety**: All VLC operations properly managed on main thread
- **Resource Management**: Automatic cleanup of VLC resources on view destruction
- **Options Normalization**: VLC options automatically prefixed and deduplicated
- **State Management**: Proper handling of app lifecycle and view attachment states