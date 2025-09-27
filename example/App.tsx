import * as React from 'react'

import { ExpoVlcPlayerView, ExpoVlcPlayerViewHandle } from 'expo-vlc-player'

const DEFAULT_STREAM = 'rtsp://172.27.1.96:50001/live/0'
const DEFAULT_OPTIONS = ['--network-caching=200', '--rtsp-tcp']

export default function App() {
  return <ExpoVlcPlayerView style={styles.player} url={DEFAULT_STREAM} options={DEFAULT_OPTIONS} resizeMode="contain" />
}

const styles = {
  player: {
    width: '100%',
    flex: 1,
  },
} as const
