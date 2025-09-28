import ExpoModulesCore
import QuartzCore
import UIKit
import VLCKit

private let defaultMediaOptions: [String] = [
  ":network-caching=200"
]

private enum OptionCategory: String {
  case player
  case media
}

final class ExpoVlcPlayerView: ExpoView {
  private let videoView = VLCPlayerDrawableView()

  private let onLoad = EventDispatcher()
  private let onPlaying = EventDispatcher()
  private let onError = EventDispatcher()

  private var mediaPlayer: VLCMediaPlayer?
  private var currentURL: URL?
  private var playerOptions: [String] = []
  private var mediaOptions: [String] = []
  private var shouldPlayWhenReady = true
  private var hasLoadDispatched = false
  private var desiredAspectRatio: String?
  private var desiredResizeMode: ResizeMode = .contain
  private var isDestroyed = false
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var wasPlayingBeforeBackground = false
  private var lastBackgroundDate: Date?
  private var resumeVerificationWorkItem: DispatchWorkItem?
  private var resumeAttemptID: UInt = 0

  required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)
    let normalized = normalizeOptions(nil)
    playerOptions = normalized.player
    mediaOptions = normalized.media
    setupView()
    registerLifecycleObservers()
  }

  deinit {
    removeLifecycleObservers()
    cleanupPlayer()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    videoView.frame = bounds
  }

  // MARK: - Public Methods

  func setStreamUrl(_ url: String?) {
    guard !isDestroyed else { return }

    let trimmed = url?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let urlString = trimmed, !urlString.isEmpty,
          let parsedURL = URL(string: urlString) else {
      stopPlayback()
      currentURL = nil
      return
    }

    currentURL = parsedURL
    loadMedia(url: parsedURL, autoPlay: shouldPlayWhenReady)
  }

  func setOptions(_ options: [String]?) {
    guard !isDestroyed else { return }

    let normalized = normalizeOptions(options)
    guard normalized.player != playerOptions || normalized.media != mediaOptions else { return }

    playerOptions = normalized.player
    mediaOptions = normalized.media

    if currentURL != nil {
      recreatePlayer()
    }
  }

  func setAspectRatio(_ ratio: String?) {
    guard !isDestroyed else { return }
    let cleaned = ratio?.trimmingCharacters(in: .whitespacesAndNewlines)
    desiredAspectRatio = cleaned?.isEmpty == true ? nil : cleaned
    applyAspectRatio()
  }

  func setResizeMode(_ mode: String?) {
    guard !isDestroyed else { return }
    desiredResizeMode = ResizeMode.fromValue(mode)
    applyResizeMode()
  }

  func setPaused(_ paused: Bool) {
    guard !isDestroyed else { return }
    shouldPlayWhenReady = !paused

    if paused {
      cancelResumeVerification()
      mediaPlayer?.pause()
    } else {
      resumeAttemptID = resumeAttemptID &+ 1
      let attemptID = resumeAttemptID
      mediaPlayer?.play()
      scheduleResumeVerification(for: attemptID)
    }
  }

  func retry() {
    guard !isDestroyed, let url = currentURL else { return }
    shouldPlayWhenReady = true
    loadMedia(url: url, autoPlay: true)
  }

  func cleanup() {
    cleanupPlayer()
  }

  // MARK: - Private Methods

  private func setupView() {
    backgroundColor = .black
    clipsToBounds = true

    videoView.backgroundColor = .black
    videoView.clipsToBounds = true
    videoView.contentMode = .scaleAspectFit
    videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(videoView)
  }

  private func registerLifecycleObservers() {
    guard lifecycleObservers.isEmpty else { return }

    let center = NotificationCenter.default

    let didEnterBackground = center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
      self?.handleAppDidEnterBackground()
    }

    let willEnterForeground = center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
      self?.handleAppWillEnterForeground()
    }

    let didBecomeActive = center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.handleAppDidBecomeActive()
    }

    lifecycleObservers.append(contentsOf: [didEnterBackground, willEnterForeground, didBecomeActive])
  }

  private func performOnMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
      block()
    } else {
      DispatchQueue.main.async(execute: block)
    }
  }

  private func removeLifecycleObservers() {
    let center = NotificationCenter.default
    for observer in lifecycleObservers {
      center.removeObserver(observer)
    }
    lifecycleObservers.removeAll()
  }

  private func createMediaPlayer() -> VLCMediaPlayer {
    let options = playerOptions

    let player: VLCMediaPlayer
    if options.isEmpty {
      player = VLCMediaPlayer()
    } else {
      player = VLCMediaPlayer(options: options)
    }

    // 设置drawable - 这是关键，必须在主线程
    player.drawable = videoView

    player.delegate = self

    return player
  }

  private func loadMedia(url: URL, autoPlay: Bool) {
    // 确保在主线程操作UI
    performOnMain { [weak self] in
      guard let self else { return }
      self.cancelResumeVerification()
      self.resumeAttemptID = self.resumeAttemptID &+ 1
      let attemptID = self.resumeAttemptID

      // 清理现有播放器
      if let player = self.mediaPlayer, player.isPlaying {
        player.stop()
      }

      if self.mediaPlayer == nil {
        self.mediaPlayer = self.createMediaPlayer()
      }

      guard let player = self.mediaPlayer else {
        self.emitError("Failed to create VLC player")
        return
      }

      player.drawable = self.videoView

      self.hasLoadDispatched = false

      // 创建媒体对象
      let media = VLCMedia(url: url)

      // 添加选项
      for option in self.mediaOptions {
        media?.addOption(option)
      }

      player.media = media

      // 应用设置
      self.applyAspectRatio()
      self.applyResizeMode()

      if autoPlay {
        // 稍微延迟播放，确保drawable设置完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          guard let self, !self.isDestroyed else { return }
          self.mediaPlayer?.play()
          self.scheduleResumeVerification(for: attemptID)
        }
      }
    }
  }

  private func stopPlayback() {
    shouldPlayWhenReady = false
    hasLoadDispatched = false
    cancelResumeVerification()

    performOnMain { [weak self] in
      guard let self else { return }
      guard let player = self.mediaPlayer else { return }
      player.drawable = nil
      player.stop()
      player.media = nil
    }
  }

  private func recreatePlayer() {
    guard let url = currentURL else { return }

    performOnMain { [weak self] in
      guard let self else { return }
      // 清理当前播放器
      if let player = self.mediaPlayer {
        player.drawable = nil
        player.stop()
        player.delegate = nil
      }
      self.mediaPlayer = nil

      // 重新创建
      self.loadMedia(url: url, autoPlay: self.shouldPlayWhenReady)
    }
  }

  private func applyAspectRatio() {
    guard let player = mediaPlayer else { return }

    DispatchQueue.main.async {
      if let ratio = self.desiredAspectRatio, !ratio.isEmpty {
        player.videoAspectRatio = ratio
      } else {
        player.videoAspectRatio = nil
      }
    }
  }

  private func applyResizeMode() {
    DispatchQueue.main.async {
      switch self.desiredResizeMode {
      case .contain:
        self.videoView.contentMode = .scaleAspectFit
      case .cover:
        self.videoView.contentMode = .scaleAspectFill
      case .stretch:
        self.videoView.contentMode = .scaleToFill
      case .fill:
        self.videoView.contentMode = .scaleAspectFill
      case .original:
        self.videoView.contentMode = .center
      }
    }
  }

  private func normalizeOptions(_ options: [String]?) -> (player: [String], media: [String]) {
    var player: [String] = []
    var media: [String] = []
    var playerSeen: [String: Int] = [:]
    var mediaSeen: [String: Int] = [:]

    func appendOption(_ rawValue: String, category: OptionCategory) {
      let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return }

      let prefixed = ExpoVlcPlayerView.ensureOptionPrefix(trimmed, category: category)
      let key = ExpoVlcPlayerView.canonicalOptionKey(prefixed, category: category)

      switch category {
      case .player:
        if let existingIndex = playerSeen[key] {
          player[existingIndex] = prefixed
        } else {
          player.append(prefixed)
          playerSeen[key] = player.count - 1
        }

      case .media:
        if let existingIndex = mediaSeen[key] {
          media[existingIndex] = prefixed
        } else {
          media.append(prefixed)
          mediaSeen[key] = media.count - 1
        }
      }
    }

    for option in defaultMediaOptions {
      appendOption(option, category: .media)
    }

    if let options, !options.isEmpty {
      for option in options {
        let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }

        if trimmed.hasPrefix(":") {
          appendOption(trimmed, category: .media)
        } else {
          appendOption(trimmed, category: .player)
        }
      }
    }

    return (player, media)
  }

  private static func canonicalOptionKey(_ option: String, category: OptionCategory) -> String {
    let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)

    var startIndex = trimmed.startIndex
    while startIndex < trimmed.endIndex && (trimmed[startIndex] == "-" || trimmed[startIndex] == ":") {
      startIndex = trimmed.index(after: startIndex)
    }

    let withoutPrefix = trimmed[startIndex...]

    let baseKey: String
    if let equalsIndex = withoutPrefix.firstIndex(of: "=") {
      baseKey = String(withoutPrefix[..<equalsIndex]).lowercased()
    } else {
      baseKey = String(withoutPrefix).lowercased()
    }

    return "\(category.rawValue)|\(baseKey)"
  }

  private static func ensureOptionPrefix(_ option: String, category: OptionCategory) -> String {
    switch category {
    case .player:
      if option.hasPrefix("--") || option.hasPrefix("-") {
        return option
      }
      if option.hasPrefix(":") {
        let withoutColon = option.dropFirst()
        return "--\(withoutColon)"
      }
      return "--\(option)"

    case .media:
      if option.hasPrefix(":") {
        return option
      }
      if option.hasPrefix("--") || option.hasPrefix("-") {
        let withoutHyphen = option.drop(while: { $0 == "-" })
        return ":\(withoutHyphen)"
      }
      return ":\(option)"
    }
  }

  private func emitError(_ message: String) {
    shouldPlayWhenReady = false
    var payload: [String: Any] = ["message": message]
    if let url = currentURL?.absoluteString {
      payload["url"] = url
    }

    DispatchQueue.main.async {
      self.onError(payload)
    }
  }

  private func scheduleResumeVerification(for attemptID: UInt) {
    resumeVerificationWorkItem?.cancel()

    guard let url = currentURL else { return }

    let workItem = DispatchWorkItem { [weak self] in
      guard let self, !self.isDestroyed, self.resumeAttemptID == attemptID else { return }
      guard let player = self.mediaPlayer else { return }

      if player.hasVideoOut {
        return
      }

      self.loadMedia(url: url, autoPlay: self.shouldPlayWhenReady)
    }

    resumeVerificationWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
  }

  private func cancelResumeVerification() {
    resumeVerificationWorkItem?.cancel()
    resumeVerificationWorkItem = nil
  }

  private func handleAppDidEnterBackground() {
    guard !isDestroyed else { return }
    cancelResumeVerification()

    if let player = mediaPlayer {
      wasPlayingBeforeBackground = player.isPlaying
      player.drawable = nil
    } else {
      wasPlayingBeforeBackground = false
    }

    lastBackgroundDate = Date()
  }

  private func handleAppWillEnterForeground() {
    guard !isDestroyed, let player = mediaPlayer else { return }
    player.drawable = videoView
  }

  private func handleAppDidBecomeActive() {
    guard !isDestroyed else { return }

    cancelResumeVerification()

    let shouldResume = wasPlayingBeforeBackground || shouldPlayWhenReady
    wasPlayingBeforeBackground = false

    let timeAway = lastBackgroundDate.map { Date().timeIntervalSince($0) } ?? 0
    lastBackgroundDate = nil

    if mediaPlayer == nil {
      guard shouldResume, let url = currentURL else { return }
      loadMedia(url: url, autoPlay: true)
      return
    }

    guard let player = mediaPlayer else { return }
    player.drawable = videoView

    guard shouldResume else { return }

    if timeAway > 3.0 {
      guard let url = currentURL else { return }
      loadMedia(url: url, autoPlay: true)
      return
    }

    resumeAttemptID = resumeAttemptID &+ 1
    let attemptID = resumeAttemptID

    DispatchQueue.main.async { [weak self] in
      guard let self, !self.isDestroyed else { return }
      self.mediaPlayer?.play()
      self.scheduleResumeVerification(for: attemptID)
    }
  }

  private func cleanupPlayer() {
    guard !isDestroyed else { return }
    isDestroyed = true

    shouldPlayWhenReady = false
    hasLoadDispatched = false
    wasPlayingBeforeBackground = false
    lastBackgroundDate = nil
    cancelResumeVerification()
    removeLifecycleObservers()

    if Thread.isMainThread {
      if let player = mediaPlayer {
        player.drawable = nil
        player.stop()
        player.delegate = nil
      }
      mediaPlayer = nil
    } else {
      DispatchQueue.main.sync { [weak self] in
        guard let self else { return }
        if let player = self.mediaPlayer {
          player.drawable = nil
          player.stop()
          player.delegate = nil
        }
        self.mediaPlayer = nil
      }
    }

    currentURL = nil
  }
}

// MARK: - VLCMediaPlayerDelegate

extension ExpoVlcPlayerView: VLCMediaPlayerDelegate {
  func mediaPlayerStateChanged(_ aNotification: Notification) {
    guard let player = mediaPlayer, !isDestroyed else { return }

    DispatchQueue.main.async {
      switch player.state {
      case .opening:
        // 视频开始加载
        print("VLC: Opening media")
        break

      case .buffering:
        // 缓冲中
        print("VLC: Buffering")
        break

      case .playing:
        print("VLC: Playing")
        self.cancelResumeVerification()
        if !self.hasLoadDispatched, let url = self.currentURL {
          self.hasLoadDispatched = true
          self.onLoad(["url": url.absoluteString])
        }
        if let url = self.currentURL {
          self.onPlaying(["url": url.absoluteString])
        }

      case .paused:
        print("VLC: Paused")
        break

      case .stopped:
        print("VLC: Stopped")
        self.cancelResumeVerification()
        self.hasLoadDispatched = false

      case .error:
        print("VLC: Error occurred")
        self.cancelResumeVerification()
        self.emitError("VLC playback error occurred")

      default:
        print("VLC: State changed to \(player.state.rawValue)")
        break
      }
    }
  }

  func mediaPlayerTimeChanged(_ aNotification: Notification) {
    // 保留用于未来的进度事件
  }
}

// MARK: - ResizeMode

private enum ResizeMode {
  case contain
  case cover
  case stretch
  case fill
  case original

  static func fromValue(_ value: String?) -> ResizeMode {
    switch value?.lowercased() {
    case "cover": return .cover
    case "stretch": return .stretch
    case "fill": return .fill
    case "original", "center": return .original
    default: return .contain
    }
  }
}

private final class VLCPlayerDrawableView: UIView {
  override class var layerClass: AnyClass {
    CAEAGLLayer.self
  }
}
