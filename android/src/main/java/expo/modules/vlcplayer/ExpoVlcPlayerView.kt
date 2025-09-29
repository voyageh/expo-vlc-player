package expo.modules.vlcplayer

import android.content.Context
import android.net.Uri
import android.os.SystemClock
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.viewevent.EventDispatcher
import expo.modules.kotlin.views.ExpoView
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.util.VLCVideoLayout
import java.util.ArrayList

class ExpoVlcPlayerView(context: Context, appContext: AppContext) : ExpoView(context, appContext), DefaultLifecycleObserver {
  private val videoLayout = VLCVideoLayout(context)
  private val lifecycleOwner: LifecycleOwner? = appContext.activityProvider?.currentActivity as? LifecycleOwner

  private val onLoad by EventDispatcher()
  private val onPlaying by EventDispatcher()
  private val onError by EventDispatcher()

  private var playerSession: PlayerSession? = null
  private var currentUri: Uri? = null

  private var desiredInitOptions: List<String> = DEFAULT_INIT_OPTIONS
  private var desiredMediaOptions: List<String> = DEFAULT_MEDIA_OPTIONS
  private var desiredAspectRatio: String? = null
  private var desiredResizeMode: ResizeMode = ResizeMode.CONTAIN

  private var shouldPlayWhenReady = true
  private var resumeWhenActive = false
  private var attachedToWindow = false
  private var released = false

  private var lastBackgroundAt: Long? = null
  private var pendingResumeElapsed: Long = 0L
  private var resumeCheckRunnable: Runnable? = null
  private var resumeAttemptId: Long = 0

  init {
    clipToPadding = true
    addView(videoLayout)
    lifecycleOwner?.lifecycle?.addObserver(this)
  }

  fun setStreamUrl(url: String?) {
    if (released) return

    val normalized = url?.trim().orEmpty()
    val uri = runCatching { Uri.parse(normalized) }.getOrNull()
    if (normalized.isEmpty() || uri == null || uri.scheme.isNullOrEmpty()) {
      currentUri = null
      stopPlayback()
      return
    }

    pendingResumeElapsed = 0
    currentUri = uri
    ensureSession().prepare(uri, autoPlay = shouldPlayWhenReady)
  }

  fun setInitOptions(options: List<String>?) {
    if (released) return

    val resolved = options?.toList() ?: DEFAULT_INIT_OPTIONS
    if (resolved == desiredInitOptions) {
      return
    }

    desiredInitOptions = resolved
    rebuildSession(autoReplay = shouldPlayWhenReady)
  }

  fun setMediaOptions(options: List<String>?) {
    if (released) return

    val resolved = options?.toList() ?: DEFAULT_MEDIA_OPTIONS
    if (resolved == desiredMediaOptions) {
      return
    }

    desiredMediaOptions = resolved
    rebuildSession(autoReplay = shouldPlayWhenReady)
  }

  fun setAspectRatio(aspectRatio: String?) {
    if (released) return
    val normalized = aspectRatio?.trim()?.takeIf { it.isNotEmpty() }
    desiredAspectRatio = normalized
    playerSession?.applyAspectRatio(normalized)
  }

  fun setResizeMode(mode: String?) {
    if (released) return
    val resolved = ResizeMode.fromValue(mode)
    desiredResizeMode = resolved
    playerSession?.applyResizeMode(resolved)
  }

  fun pause() {
    if (released) return
    shouldPlayWhenReady = false
    playerSession?.pause()
    cancelResumeVerification()
  }

  fun resume() {
    if (released) return
    shouldPlayWhenReady = true
    pendingResumeElapsed = if (lastBackgroundAt != null) elapsedSinceBackground() else 0L
    if (attachedToWindow) {
      playerSession?.playWhenReady()
    }
  }

  fun stopPlayback() {
    if (released) return
    shouldPlayWhenReady = false
    resumeWhenActive = false
    playerSession?.stop()
    cancelResumeVerification()
  }

  fun retry() {
    if (released) return
    val uri = currentUri ?: return
    shouldPlayWhenReady = true
    cancelResumeVerification()
    ensureSession().prepare(uri, autoPlay = true)
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    if (released) return
    attachedToWindow = true
    playerSession?.attach(videoLayout)

    if (shouldPlayWhenReady && currentUri != null) {
      pendingResumeElapsed = if (lastBackgroundAt != null) elapsedSinceBackground() else 0L
      playerSession?.playWhenReady()
    } else {
      cancelResumeVerification()
    }
  }

  override fun onDetachedFromWindow() {
    if (!released) {
      playerSession?.pause()
      playerSession?.detach()
      attachedToWindow = false
      cancelResumeVerification()
    }
    super.onDetachedFromWindow()
  }

  override fun onStop(owner: LifecycleOwner) {
    if (released) return
    resumeWhenActive = playerSession?.isPlaying() == true
    lastBackgroundAt = SystemClock.elapsedRealtime()
    playerSession?.pause()
    playerSession?.detach()
    cancelResumeVerification()
  }

  override fun onStart(owner: LifecycleOwner) {
    if (released) return

    if (attachedToWindow) {
      playerSession?.attach(videoLayout)
    }

    val shouldResume = resumeWhenActive || shouldPlayWhenReady
    resumeWhenActive = false

    if (shouldResume && attachedToWindow && currentUri != null) {
      pendingResumeElapsed = if (lastBackgroundAt != null) elapsedSinceBackground() else 0L
      playerSession?.playWhenReady()
    } else {
      cancelResumeVerification()
    }

    lastBackgroundAt = null
  }

  fun release() {
    if (released) return
    released = true
    shouldPlayWhenReady = false
    attachedToWindow = false
    resumeWhenActive = false
    cancelResumeVerification()
    lifecycleOwner?.lifecycle?.removeObserver(this)
    playerSession?.release()
    playerSession = null
    currentUri = null
    lastBackgroundAt = null
  }

  override fun onDestroy(owner: LifecycleOwner) {
    owner.lifecycle.removeObserver(this)
    release()
  }

  private fun ensureSession(): PlayerSession {
    val session = playerSession
    val targetUri = currentUri

    if (session != null && session.matches(desiredInitOptions, desiredMediaOptions)) {
      return session
    }

    playerSession?.release()
    val newSession = PlayerSession(context, desiredInitOptions, desiredMediaOptions)
    newSession.applyAspectRatio(desiredAspectRatio)
    newSession.applyResizeMode(desiredResizeMode)
    if (attachedToWindow) {
      newSession.attach(videoLayout)
    }
    playerSession = newSession

    if (targetUri != null) {
      newSession.prepare(targetUri, autoPlay = shouldPlayWhenReady)
    }

    return newSession
  }

  private fun rebuildSession(autoReplay: Boolean) {
    val uri = currentUri ?: return
    val session = ensureSession()
    session.prepare(uri, autoPlay = autoReplay)
  }

  private fun elapsedSinceBackground(): Long =
    lastBackgroundAt?.let { SystemClock.elapsedRealtime() - it } ?: 0L

  private fun scheduleResumeVerification() {
    val uri = currentUri ?: return
    val session = playerSession ?: return
    if (pendingResumeElapsed <= 0L) {
      return
    }

    resumeAttemptId += 1
    val attemptId = resumeAttemptId

    resumeCheckRunnable?.let { videoLayout.removeCallbacks(it) }

    val runnable = Runnable {
      if (released || attemptId != resumeAttemptId) {
        return@Runnable
      }

      val activeSession = playerSession ?: return@Runnable
      if (activeSession.hasVideoOutput()) {
        return@Runnable
      }

      pendingResumeElapsed = RELOAD_THRESHOLD_MS
      ensureSession().prepare(uri, autoPlay = shouldPlayWhenReady)
    }

    resumeCheckRunnable = runnable

    val elapsed = pendingResumeElapsed
    pendingResumeElapsed = 0

    val delay = if (elapsed > RELOAD_THRESHOLD_MS) {
      RESUME_VERIFY_DELAY_LONG_MS
    } else {
      RESUME_VERIFY_DELAY_MS
    }

    videoLayout.postDelayed(runnable, delay)
  }

  private fun cancelResumeVerification() {
    resumeAttemptId += 1
    resumeCheckRunnable?.let { videoLayout.removeCallbacks(it) }
    resumeCheckRunnable = null
    pendingResumeElapsed = 0
  }

  private inner class PlayerSession(
    context: Context,
    private val initOptions: List<String>,
    private val mediaOptions: List<String>,
  ) {
    private val libVlc = LibVLC(context.applicationContext, ArrayList(initOptions))
    private val mediaPlayer = MediaPlayer(libVlc)

    private var attached = false
    private var pendingLoadEvent = false
    private var playWhenAttached = false
    private var appliedAspectRatio: String? = null
    private var appliedScale: MediaPlayer.ScaleType? = null
    private var loadedUri: Uri? = null

    private val eventListener = MediaPlayer.EventListener { event ->
      when (event.type) {
        MediaPlayer.Event.Playing -> {
          val uri = loadedUri
          if (pendingLoadEvent && uri != null) {
            pendingLoadEvent = false
            onLoad(mapOf("url" to uri.toString()))
          }
          uri?.let { onPlaying(mapOf("url" to it.toString())) }
          cancelResumeVerification()
        }

        MediaPlayer.Event.Stopped -> {
          cancelResumeVerification()
          pendingLoadEvent = false
        }

        MediaPlayer.Event.EncounteredError -> {
          cancelResumeVerification()
          pendingLoadEvent = false
          playWhenAttached = false
          val uri = loadedUri
          onError(mapOf(
            "message" to "Encountered playback error",
            "url" to (uri?.toString() ?: ""),
          ))
        }
      }
    }

    init {
      mediaPlayer.setEventListener(eventListener)
    }

    fun prepare(uri: Uri, autoPlay: Boolean) {
      loadedUri = uri
      playWhenAttached = autoPlay
      pendingLoadEvent = true

      runCatching {
        if (mediaPlayer.isPlaying) {
          mediaPlayer.stop()
        }
      }

      mediaPlayer.media?.release()
      val media = Media(libVlc, uri).apply {
        setHWDecoderEnabled(true, false)
      }
      mediaOptions.forEach { option ->
        media.addOption(option)
      }
      mediaPlayer.media = media
      media.release()

      appliedAspectRatio?.let { applyAspectRatio(it) }
      appliedScale?.let { mediaPlayer.setVideoScale(it) }

      if (autoPlay && attached) {
        playWhenReady()
      }
    }

    fun playWhenReady() {
      if (!attached) {
        playWhenAttached = true
        return
      }
      playWhenAttached = true
      scheduleResumeVerification()
      runCatching { mediaPlayer.play() }.onFailure { error ->
        playWhenAttached = false
        onError(
          mapOf(
            "message" to (error?.message ?: "Unable to start playback"),
            "url" to (loadedUri?.toString() ?: ""),
          ),
        )
      }
    }

    fun pause() {
      playWhenAttached = false
      runCatching { mediaPlayer.pause() }
    }

    fun stop() {
      playWhenAttached = false
      pendingLoadEvent = false
      runCatching { mediaPlayer.stop() }
      mediaPlayer.media?.release()
      mediaPlayer.media = null
      loadedUri = null
    }

    fun attach(layout: VLCVideoLayout) {
      if (!attached) {
        mediaPlayer.attachViews(layout, null, false, true)
        attached = true
      }
      if (playWhenAttached) {
        playWhenReady()
      }
    }

    fun detach() {
      if (attached) {
        mediaPlayer.detachViews()
        attached = false
      }
    }

    fun applyAspectRatio(aspectRatio: String?) {
      appliedAspectRatio = aspectRatio
      runCatching { mediaPlayer.setAspectRatio(aspectRatio) }
    }

    fun applyResizeMode(mode: ResizeMode) {
      val scaleType = mode.toScaleType()
      appliedScale = scaleType
      runCatching { mediaPlayer.setVideoScale(scaleType) }
    }

    fun isPlaying(): Boolean = mediaPlayer.isPlaying

    fun hasVideoOutput(): Boolean = mediaPlayer.videoTracks.isNotEmpty()

    fun matches(init: List<String>, media: List<String>): Boolean =
      initOptions == init && mediaOptions == media

    fun release() {
      stop()
      detach()
      mediaPlayer.setEventListener(null)
      mediaPlayer.release()
      libVlc.release()
    }
  }

  private enum class ResizeMode {
    CONTAIN,
    COVER,
    STRETCH,
    FILL,
    ORIGINAL;

    fun toScaleType(): MediaPlayer.ScaleType = when (this) {
      CONTAIN -> MediaPlayer.ScaleType.SURFACE_FIT_SCREEN
      COVER -> MediaPlayer.ScaleType.SURFACE_FILL
      STRETCH -> MediaPlayer.ScaleType.SURFACE_FILL
      FILL -> MediaPlayer.ScaleType.SURFACE_BEST_FIT
      ORIGINAL -> MediaPlayer.ScaleType.SURFACE_ORIGINAL
    }

    companion object {
      fun fromValue(value: String?): ResizeMode = when (value?.lowercase()) {
        "cover" -> COVER
        "stretch" -> STRETCH
        "fill" -> FILL
        "original", "center" -> ORIGINAL
        else -> CONTAIN
      }
    }
  }

  private companion object {
    private val DEFAULT_INIT_OPTIONS = listOf(
      "--rtsp-tcp"
    )
    private val DEFAULT_MEDIA_OPTIONS = listOf(
      ":network-caching=200",
      ":rtsp-caching=200"
    )

    private const val RELOAD_THRESHOLD_MS = 2_000L
    private const val RESUME_VERIFY_DELAY_MS = 400L
    private const val RESUME_VERIFY_DELAY_LONG_MS = 1_000L
  }
}
