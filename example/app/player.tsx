import * as React from 'react'

import { ExpoVlcPlayerView } from 'expo-vlc-player'

export default function App() {
  return <ExpoVlcPlayerView style={styles.player} url="rtsp://172.27.1.96:50001/live/0" resizeMode="contain" />
}

const styles = {
  player: {
    width: '100%',
    flex: 1,
  },
} as const
