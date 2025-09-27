import type { StyleProp, ViewStyle } from 'react-native';

export type VlcPlayerEventPayload = {
  url: string;
};

export type VlcPlayerErrorPayload = {
  url?: string;
  message: string;
};

export type ExpoVlcPlayerViewProps = {
  url?: string;
  paused?: boolean;
  options?: string[];
  videoAspectRatio?: string;
  resizeMode?: 'contain' | 'cover' | 'stretch' | 'fill' | 'original';
  onLoad?: (event: { nativeEvent: VlcPlayerEventPayload }) => void;
  onPlaying?: (event: { nativeEvent: VlcPlayerEventPayload }) => void;
  onError?: (event: { nativeEvent: VlcPlayerErrorPayload }) => void;
  style?: StyleProp<ViewStyle>;
};

export type ExpoVlcPlayerViewHandle = {
  retry: () => Promise<void>;
};
