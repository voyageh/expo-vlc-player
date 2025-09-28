import { router } from 'expo-router'
import * as React from 'react'
import { Button, View } from 'react-native'

export default function App() {
  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <Button title="Go to Player" onPress={() => router.push('./player')} />
    </View>
  )
}
