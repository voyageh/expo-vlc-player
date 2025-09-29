import ExpoModulesCore

public final class ExpoVlcPlayerModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoVlcPlayer")

    View(ExpoVlcPlayerView.self) {
      Prop("url") { (view: ExpoVlcPlayerView, value: String?) in
        DispatchQueue.main.async {
          view.setStreamUrl(value)
        }
      }

      Prop("paused") { (view: ExpoVlcPlayerView, paused: Bool) in
        DispatchQueue.main.async {
          view.setPaused(paused)
        }
      }

      Prop("initOptions") { (view: ExpoVlcPlayerView, options: [String]?) in
        DispatchQueue.main.async {
          view.setInitOptions(options)
        }
      }

      Prop("mediaOptions") { (view: ExpoVlcPlayerView, options: [String]?) in
        DispatchQueue.main.async {
          view.setMediaOptions(options)
        }
      }

      Prop("videoAspectRatio") { (view: ExpoVlcPlayerView, ratio: String?) in
        DispatchQueue.main.async {
          view.setAspectRatio(ratio)
        }
      }

      Prop("resizeMode") { (view: ExpoVlcPlayerView, mode: String?) in
        DispatchQueue.main.async {
          view.setResizeMode(mode)
        }
      }

      Events("onLoad", "onPlaying", "onError")
    }

    AsyncFunction("retry") { (viewTag: Int) -> Void in
      guard let appContext = self.appContext,
            let view = appContext.findView(withTag: viewTag, ofType: ExpoVlcPlayerView.self) else {
        throw Exceptions.ViewNotFound((tag: viewTag, type: ExpoVlcPlayerView.self))
      }
      view.retry()
    }
  }
}
