import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'dart:developer' as console; // For logging

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isInitialized = false;
  String? _currentRecordingPath;

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _silenceTimer;
  Timer? _timeoutTimer;
  Completer<List<int>?>? _recordingCompleter;

  /// Initializes the service, requesting necessary permissions.
  /// Returns true if successful, false otherwise.
  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        console.log('Microphone permission not granted');
        return false;
      }
      _isInitialized = true;
      console.log('AudioRecordingService initialized successfully.');
      return true;
    } catch (e) {
      console.log('Error initializing AudioRecordingService: $e');
      return false;
    }
  }

  /// Starts recording audio with silence detection and a timeout.
  ///
  /// [timeoutDuration]: Maximum duration for the recording.
  /// [silenceDetectionDuration]: How long silence (amplitude below threshold) must last to stop recording.
  /// [silenceThresholdDb]: Amplitude level (in dBFS, typically negative) below which is considered silence.
  /// [amplitudeCheckInterval]: How often to check the audio amplitude for silence detection.
  ///
  /// Returns a Future containing the audio bytes as List<int>, or null on error/failure.
  Future<List<int>?> startRecording({
    Duration timeoutDuration = const Duration(seconds: 5),
    Duration silenceDetectionDuration = const Duration(seconds: 2),
    double silenceThresholdDb = -40.0, 
    Duration amplitudeCheckInterval = const Duration(milliseconds: 500),
  }) async {
    if (!_isInitialized) {
      final initialized = await init();
      if (!initialized) {
        console.log(
          'AudioRecordingService not initialized, cannot start recording.',
        );
        return null;
      }
    }

    if (await _recorder.isRecording() ||
        (_recordingCompleter != null && !_recordingCompleter!.isCompleted)) {
      console.log('Recording session already in progress.');
      return _recordingCompleter
          ?.future; // Return existing future if already running
    }

    _recordingCompleter = Completer<List<int>?>();

    try {
      final tempDir = await getTemporaryDirectory();
      // Using .wav for broader compatibility if AAC/M4A causes issues, though AAC is good for size.
      // For ElevenLabs, m4a (AAC) is fine.
      _currentRecordingPath =
          '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // AAC is a good default
        sampleRate: 44100,
        bitRate: 128000, // 128 kbps
        numChannels: 1, // Mono
      );

      await _recorder.start(config, path: _currentRecordingPath!);
      console.log('Recording started: $_currentRecordingPath');

      // Overall timeout for the recording
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(timeoutDuration, () {
        console.log(
          'Recording timeout reached (${timeoutDuration.inSeconds}s).',
        );
        _stopRecordingAndProcess(reason: 'timeout');
      });

      // Silence detection
      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder.onAmplitudeChanged(amplitudeCheckInterval).listen((
        amp,
      ) {
        // console.log('Current amplitude: \${amp.current} dBFS');
        if (amp.current < silenceThresholdDb) {
          // Potential silence
          if (_silenceTimer == null || !_silenceTimer!.isActive) {
            // console.log('Potential silence detected (<\${silenceThresholdDb}dBFS), starting silence timer (\${silenceDetectionDuration.inSeconds}s).');
            _silenceTimer = Timer(silenceDetectionDuration, () {
              console.log(
                'Confirmed silence for ${silenceDetectionDuration.inSeconds}s.',
              );
              _stopRecordingAndProcess(reason: 'silence');
            });
          }
        } else {
          // Sound detected
          _silenceTimer?.cancel();
          // console.log('Sound detected (>\${silenceThresholdDb}dBFS), silence timer cancelled.');
        }
      });

      return _recordingCompleter!.future;
    } catch (e) {
      console.log('Error starting recording: $e');
      await _cleanupOnError();
      if (_recordingCompleter != null && !_recordingCompleter!.isCompleted) {
        _recordingCompleter!.complete(null);
      }
      _recordingCompleter = null; // Nullify to allow new session
      return null;
    }
  }

  Future<void> _stopRecordingAndProcess({String reason = 'unknown'}) async {
    if (_recordingCompleter == null || _recordingCompleter!.isCompleted) {
      // No active recording session or it's already completed.
      _cleanupTimersAndSubscription(); // Still good to clean up timers if somehow active
      return;
    }

    console.log('Stopping recording due to: $reason...');
    String? path;
    try {
      if (await _recorder.isRecording()) {
        path = await _recorder.stop();
        console.log('Recorder stopped. File at: $path');
      } else {
        console.log(
          'Recorder was not recording, but processing requested. Path: $_currentRecordingPath',
        );
        path =
            _currentRecordingPath; // Use the path we started with if stop() wasn't called or needed
      }
    } catch (e) {
      console.log('Error stopping recorder: $e');
      if (!_recordingCompleter!.isCompleted) {
        _recordingCompleter!.complete(null);
      }
      await _cleanupOnError();
      _recordingCompleter = null;
      return;
    }

    _cleanupTimersAndSubscription();

    if (path == null) {
      console.log('Recording path is null after attempting to stop.');
      if (!_recordingCompleter!.isCompleted) {
        _recordingCompleter!.complete(null);
      }
      _cleanupPath();
      _recordingCompleter = null;
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        final audioBytes = await file.readAsBytes();
        console.log('Read ${audioBytes.length} bytes from $path.');
        if (!_recordingCompleter!.isCompleted) {
          _recordingCompleter!.complete(audioBytes);
        }
        try {
          await file.delete();
        } catch (e) {
          console.log('Error deleting temporary file $path: $e');
        }
        console.log('Temporary file $path processed and delete attempted.');
      } else {
        console.log('Recorded file does not exist at $path.');
        if (!_recordingCompleter!.isCompleted) {
          _recordingCompleter!.complete(null);
        }
      }
    } catch (e) {
      console.log('Error processing recorded file: $e');
      if (!_recordingCompleter!.isCompleted) {
        _recordingCompleter!.complete(null);
      }
    } finally {
      _cleanupPath();
      _recordingCompleter = null; // Nullify to allow new session
    }
  }

  void _cleanupTimersAndSubscription() {
    _timeoutTimer?.cancel();
    _silenceTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _timeoutTimer = null;
    _silenceTimer = null;
    _amplitudeSubscription = null;
  }

  void _cleanupPath() {
    _currentRecordingPath = null;
  }

  Future<void> _cleanupOnError() async {
    _cleanupTimersAndSubscription();
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          console.log("Error deleting file during cleanupOnError: $e");
        }
      }
    }
    _cleanupPath();
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      console.log("Error stopping recorder during cleanupOnError: \$e");
    }
  }

  /// Call this method to release resources when the service is no longer needed.
  Future<void> dispose() async {
    await _cleanupOnError(); // General cleanup
    await _recorder.dispose();
    if (_recordingCompleter != null && !_recordingCompleter!.isCompleted) {
      _recordingCompleter!.complete(null); // Ensure completer is finalized
    }
    _recordingCompleter = null;
    console.log('AudioRecordingService disposed.');
  }
}
