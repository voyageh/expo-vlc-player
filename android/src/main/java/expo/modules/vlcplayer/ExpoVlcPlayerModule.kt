package expo.modules.vlcplayer

import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class ExpoVlcPlayerModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("ExpoVlcPlayer")

    View(ExpoVlcPlayerView::class) {
      Prop("url") { view: ExpoVlcPlayerView, url: String? ->
        view.setStreamUrl(url)
      }

      Prop("paused") { view: ExpoVlcPlayerView, paused: Boolean ->
        if (paused) {
          view.pause()
        } else {
          view.resume()
        }
      }

      Prop("initOptions") { view: ExpoVlcPlayerView, options: List<String>? ->
        view.setInitOptions(options)
      }

      Prop("mediaOptions") { view: ExpoVlcPlayerView, options: List<String>? ->
        view.setMediaOptions(options)
      }

      Prop("videoAspectRatio") { view: ExpoVlcPlayerView, aspectRatio: String? ->
        view.setAspectRatio(aspectRatio)
      }

      Prop("resizeMode") { view: ExpoVlcPlayerView, resizeMode: String? ->
        view.setResizeMode(resizeMode)
      }

      Events("onLoad", "onPlaying", "onError")

      OnViewDestroys { view: ExpoVlcPlayerView ->
        view.release()
      }
    }

    AsyncFunction("retry") { viewTag: Int ->
      val view = appContext.findView<ExpoVlcPlayerView>(viewTag)
        ?: throw Exceptions.ViewNotFound(ExpoVlcPlayerView::class, viewTag)

      view.retry()
    }
  }
}
