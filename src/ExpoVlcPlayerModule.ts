import { requireNativeModule } from 'expo';

export type ExpoVlcPlayerNativeModule = {
  retry(viewTag: number): Promise<void>;
};

export default requireNativeModule<ExpoVlcPlayerNativeModule>('ExpoVlcPlayer');
