# Expo VLC Player

A simple Expo wrapper for VLC Player, allowing you to stream RTSP or other network video sources directly inside your Expo React Native app.

## Installation

```bash
npm install @wniu/expo-vlc-player
```

or using **yarn**:

```bash
yarn add @wniu/expo-vlc-player
```

## Usage

Import and use the `ExpoVlcPlayerView` component in your React Native project:

```tsx
import React from "react";
import { StyleSheet, View } from "react-native";
import { ExpoVlcPlayerView } from "@wniu/expo-vlc-player";

export default function App() {
  return (
    <View style={styles.container}>
      <ExpoVlcPlayerView
        style={styles.player}
        url="rtsp://172.27.1.96:50001/live/0"
        options={["--network-caching=200", "--rtsp-tcp"]}
        resizeMode="contain"
        paused={false}
        videoAspectRatio="16:9"
        onLoad={(e) => console.log("Loaded", e.nativeEvent)}
        onPlaying={(e) => console.log("Playing", e.nativeEvent)}
        onError={(e) => console.error("Error", e.nativeEvent)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#000",
    justifyContent: "center",
    alignItems: "center",
  },
  player: {
    width: "100%",
    height: 300,
  },
});
```

## Props

| Prop              | Type                                | Description                                                                 |
|-------------------|-------------------------------------|-----------------------------------------------------------------------------|
| `url`             | `string`                            | The video stream URL (RTSP, HTTP, etc.).                                    |
| `paused`          | `boolean`                           | Whether playback is paused. Default: `false`.                               |
| `options`         | `string[]`                          | VLC options (e.g., `["--network-caching=200", "--rtsp-tcp"]`).              |
| `videoAspectRatio`| `string`                            | Aspect ratio for the video (e.g., `"16:9"`, `"4:3"`).                       |
| `resizeMode`      | `'contain' \| 'cover' \| 'stretch' \| 'fill' \| 'original'` | How the video should be scaled inside the player.                           |
| `onLoad`          | `(event: { nativeEvent: VlcPlayerEventPayload }) => void` | Callback when the video is loaded.                                          |
| `onPlaying`       | `(event: { nativeEvent: VlcPlayerEventPayload }) => void` | Callback when the video starts playing.                                     |
| `onError`         | `(event: { nativeEvent: VlcPlayerErrorPayload }) => void` | Callback when an error occurs.                                              |
| `style`           | `StyleProp<ViewStyle>`              | React Native style object for layout customization.                         |

## Example Options

- `--network-caching=200` → Reduces network buffer for faster response.  
- `--rtsp-tcp` → Forces RTSP over TCP instead of UDP.  

## License

MIT
