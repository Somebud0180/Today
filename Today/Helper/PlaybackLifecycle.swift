/// Resuming foreground playback is allowed only for a visible player that was playing.
struct PlaybackLifecycle {
    private var visible = true
    private var shouldResume = false

    mutating func interrupt(wasPlaying: Bool) { shouldResume = visible && wasPlaying }
    mutating func setVisible(_ value: Bool) {
        visible = value
        if !value { shouldResume = false }
    }
    mutating func resumeIfNeeded() -> Bool {
        defer { shouldResume = false }
        return visible && shouldResume
    }
}
