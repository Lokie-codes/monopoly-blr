enum SoundEffect {
  diceRoll,
  buttonClick,
  buyProperty,
  payRent,
  passGo,
  goToJail,
  chat,
  turnStart,
  gameStart,
  gameOver,
}

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  bool _soundEnabled = false; // Disabled by default until assets are added
  double _volume = 0.7;

  bool get soundEnabled => _soundEnabled;
  double get volume => _volume;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }

  /// Play a sound effect
  /// Currently disabled - to enable sounds, add audio files to assets/sounds/
  /// and update this method to use AssetSource
  Future<void> play(SoundEffect effect) async {
    if (!_soundEnabled) return;
    
    // Sound effects are currently disabled
    // To enable: Add mp3 files to assets/sounds/ and configure pubspec.yaml
    // Example:
    //   final player = AudioPlayer();
    //   await player.play(AssetSource('sounds/dice_roll.mp3'));
  }

  void dispose() {
    // No resources to dispose currently
  }
}
