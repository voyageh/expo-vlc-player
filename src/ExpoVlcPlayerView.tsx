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
  { resizeMode = 'contain', options, paused, ...rest },
  ref,
) {
  const nativeRef = React.useRef<React.ComponentRef<typeof NativeView>>(null);

  const filteredOptions = React.useMemo(
    () => options?.map((value) => value.trim()).filter((value) => value.length > 0),
    [options],
  );

  const nativeProps: ExpoVlcPlayerViewProps = {
    resizeMode,
    paused: paused ?? false,
    ...rest,
  };

  if (filteredOptions && filteredOptions.length > 0) {
    nativeProps.options = filteredOptions;
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
