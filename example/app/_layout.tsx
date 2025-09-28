import { Stack } from 'expo-router'
import { ThemeProvider, DefaultTheme, DarkTheme } from '@react-navigation/native'
import { useColorScheme } from 'react-native'

export default function RootLayout() {
  const theme = useColorScheme()
  return (
    <ThemeProvider value={theme === 'dark' ? DarkTheme : DefaultTheme}>
      <Stack />
    </ThemeProvider>
  )
}
