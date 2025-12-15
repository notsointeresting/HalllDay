import 'package:web/web.dart' as web;

/// Service to synthesize audio using the Web Audio API (package:web).
/// Reproduces the exact sounds from the legacy Kiosk (Oscillators).
class SoundService {
  web.AudioContext? _ctx;

  // Singleton
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  /// Initialize Audio Context (must be resumed on gesture usually)
  void init() {
    _ctx ??= web.AudioContext();
    if (_ctx!.state == 'suspended') {
      _ctx!.resume();
    }
  }

  /// Play a tone using an oscillator.
  void playTone(
    double freq,
    String type,
    double duration, {
    double startTime = 0.0,
    double volume = 0.1,
    double rampTime = 0.05,
  }) {
    init();
    final ctx = _ctx!;
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();

    osc.type = type;

    // Convert currentTime (num) to double
    final double t = ctx.currentTime.toDouble() + startTime;

    // Frequency
    osc.frequency.setValueAtTime(freq, t);

    // Envelope
    gain.gain.setValueAtTime(0, t);
    gain.gain.linearRampToValueAtTime(volume, t + rampTime);
    gain.gain.exponentialRampToValueAtTime(0.001, t + duration);

    // Connect
    osc.connect(gain);
    gain.connect(ctx.destination);

    // Start/Stop
    osc.start(t);
    osc.stop(t + duration);
  }

  /// Ding-Dong-Ding (C Major)
  void playSuccessOut() {
    playTone(523.25, 'sine', 0.6, startTime: 0.0); // C5
    playTone(659.25, 'sine', 0.6, startTime: 0.1); // E5
    playTone(783.99, 'sine', 0.8, startTime: 0.2); // G5
  }

  /// Ding-Dong-Ding Reversed (Return)
  void playSuccessIn() {
    playTone(783.99, 'sine', 0.5, startTime: 0.0); // G5
    playTone(659.25, 'sine', 0.5, startTime: 0.1); // E5
    playTone(523.25, 'sine', 0.8, startTime: 0.2); // C5
  }

  /// Buzz (Error/Deny)
  void playError() {
    init();
    // Two dissonant tones
    playTone(300, 'triangle', 0.4, startTime: 0.0, volume: 0.15);
    playTone(350, 'triangle', 0.4, startTime: 0.05, volume: 0.15);
  }

  /// Dramatic Drop (Banned)
  void playAlert() {
    init();
    final ctx = _ctx!;
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();

    osc.type = 'sawtooth';

    final t = ctx.currentTime.toDouble();

    // Frequency Sweep (150Hz -> 50Hz)
    osc.frequency.setValueAtTime(150, t);
    osc.frequency.linearRampToValueAtTime(50, t + 2.0);

    // Volume Envelope
    gain.gain.setValueAtTime(0.3, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 2.5);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start(t);
    osc.stop(t + 2.5);
  }

  /// Processing Blip
  void playProcessing() {
    playTone(800, 'sine', 0.1, startTime: 0, volume: 0.05, rampTime: 0.01);
  }
}
