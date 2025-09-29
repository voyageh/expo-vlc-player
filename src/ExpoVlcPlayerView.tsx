import { requireNativeView } from 'expo';
import * as React from 'react';
import { findNodeHandle } from 'react-native';

import ExpoVlcPlayerModule from './ExpoVlcPlayerModule';
import {
  ExpoVlcPlayerViewHandle,
  ExpoVlcPlayerViewProps,
} from './ExpoVlcPlayer.types';

const NativeView = requireNativeView<ExpoVlcPlayerViewProps>('ExpoVlcPlayer') as React.ComponentType<
  ExpoVlcPlayerViewProps & React.RefAttributes<any>
>;

const ExpoVlcPlayerView = React.forwardRef<
  ExpoVlcPlayerViewHandle,
  ExpoVlcPlayerViewProps
>(function ExpoVlcPlayerView(
  { resizeMode = 'contain', initOptions, mediaOptions, paused, ...rest },
  ref,
) {
  const nativeRef = React.useRef<React.ComponentRef<typeof NativeView>>(null);

  const nativeProps: ExpoVlcPlayerViewProps = {
    resizeMode,
    paused: paused ?? false,
    ...rest,
  };

  if (initOptions && initOptions.length > 0) {
    nativeProps.initOptions = initOptions;
  }

  if (mediaOptions && mediaOptions.length > 0) {
    nativeProps.mediaOptions = mediaOptions;
  }

  React.useImperativeHandle(
    ref,
    () => ({
      retry: async () => {
        const handle = findNodeHandle(nativeRef.current);
        if (handle == null) {
          return;
        }
        await ExpoVlcPlayerModule.retry(handle);
      },
    }),
    [],
  );

  return <NativeView ref={nativeRef} {...nativeProps} />;
});

export default ExpoVlcPlayerView;
