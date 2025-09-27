# Repository Guidelines

## Project Structure & Module Organization
The Expo-facing TypeScript source lives in `src/`, with `index.ts` re-exporting the public API and `ExpoVlcPlayerView.tsx` bridging to the native view. Generated artifacts land in `build/` after a module build. Native shims reside in `android/src/main/java/expo/modules/vlcplayer/` and `ios/` for Swift scaffolding (Android is currently the only platform with playback). The `example/` directory holds the Expo app used for local testing, with assets in `example/assets/` and the entry point in `example/App.tsx`.

## Build, Test, and Development Commands
Run `npm run build` to compile the module into `build/`. `npm run clean` resets generated outputs. `npm run lint` applies the Expo Module ESLint and formatting rules. `npm run test` executes the Jest suite configured by `expo-module-scripts`. Launch the showcase app from `example/` via `npm run start`, or target Android with `npm run android` from the same directory (the iOS runner is intentionally pending).

## Coding Style & Naming Conventions
TypeScript files use two-space indentation and ES module imports. Keep component and module names in PascalCase (e.g., `ExpoVlcPlayerView`) and props/interfaces suffixed with `Props` or `Options`. Prefer React function components and avoid default exports on shared utilities. Run `npm run lint` (add `-- --fix` when safe) before sending a PR to ensure Prettier and ESLint alignment.

## Testing Guidelines
Create Jest tests alongside the source in `src/__tests__/` with filenames like `ExpoVlcPlayerView.test.tsx`. Exercise both the TypeScript API surface and prop wiring to the native view. For native behaviour, rely on the example app and document manual verification steps in the PR. Aim to cover new logic paths above 80% statements and explain any intentional gaps.

## Commit & Pull Request Guidelines
Follow the existing imperative, present-tense style (`Add Expo player view bindings`). Squash commits that represent a single change set. PRs should include a short summary, testing notes (commands run plus results), and screenshots or screen recordings when UI is affected. Link related GitHub issues and call out any native platform considerations or follow-up work.

## Native Module Tips
Android is the source of truth today; mirror changes into `ios/` only when the native player work begins so the stubs stay compilable. If you add new props, define them in `ExpoVlcPlayer.types.ts`, thread them through the view component, and document usage in the README. Always run the Android example app after native changes.
