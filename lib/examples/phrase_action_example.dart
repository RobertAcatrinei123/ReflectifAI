import 'package:flutter/material.dart';
import 'dart:developer' as console;
import 'package:reflectifai/service/action_trigger_service.dart';

/// Example of how to integrate the ActionTriggerService into your app
class PhraseActionExample extends StatefulWidget {
  const PhraseActionExample({super.key});

  @override
  State<PhraseActionExample> createState() => _PhraseActionExampleState();
}

class _PhraseActionExampleState extends State<PhraseActionExample> {
  final ActionTriggerService _actionService = ActionTriggerService();
  String _lastAction = 'None';
  bool _isListening = false;
  final List<String> _actionHistory = [];

  @override
  void initState() {
    super.initState();
    _setupActionService();
  }

  Future<void> _setupActionService() async {
    // Set up callbacks for different types of actions
    _actionService.onWakeWordDetected = () {
      _handleWakeWord();
    };

    _actionService.onStopCommand = () {
      _handleStopCommand();
    };

    _actionService.onCustomAction = (action) {
      _handleCustomAction(action);
    };

    // Initialize the service
    await _actionService.initialize();
  }

  void _handleWakeWord() {
    setState(() {
      _lastAction = 'Wake Word Detected';
      _actionHistory.insert(
        0,
        'Wake Word - ${DateTime.now().toString().substring(11, 19)}',
      );
    });

    // You could trigger UI changes, start other services, etc.
    console.log('Wake word detected - app is now listening');

    // Example: Show a snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wake word detected! App is listening...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleStopCommand() {
    setState(() {
      _lastAction = 'Stop Command';
      _actionHistory.insert(
        0,
        'Stop Command - ${DateTime.now().toString().substring(11, 19)}',
      );
    });

    _stopListening();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stop command detected. Stopping detection.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleCustomAction(String action) {
    setState(() {
      _lastAction = 'Action: $action';
      _actionHistory.insert(
        0,
        '$action - ${DateTime.now().toString().substring(11, 19)}',
      );

      // Keep only last 20 actions
      if (_actionHistory.length > 20) {
        _actionHistory.removeRange(20, _actionHistory.length);
      }
    });

    // Handle specific actions
    switch (action) {
      case 'take_note':
        _showNoteDialog();
        break;
      case 'start_recording':
        _startRecording();
        break;
      case 'save_recording':
        _saveRecording();
        break;
      case 'open_settings':
        _openSettings();
        break;
      case 'show_menu':
        _showMenu();
        break;
      default:
        console.log('Unknown action: $action');
    }
  }

  void _showNoteDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Take Note'),
            content: const Text(
              'Note-taking feature triggered by voice command!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _startRecording() {
    console.log('Starting recording triggered by voice command');
    // Implement your recording logic here
  }

  void _saveRecording() {
    console.log('Saving recording triggered by voice command');
    // Implement your save logic here
  }

  void _openSettings() {
    console.log('Opening settings triggered by voice command');
    // Navigate to settings or show settings dialog
  }

  void _showMenu() {
    console.log('Showing menu triggered by voice command');
    // Show app menu or navigation drawer
  }

  Future<void> _startListening() async {
    final success = await _actionService.startDetection();
    if (success) {
      setState(() {
        _isListening = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start detection. Check permissions.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopListening() async {
    await _actionService.stopDetection();
    setState(() {
      _isListening = false;
    });
  }

  @override
  void dispose() {
    _actionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Action Demo'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Control panel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Actions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isListening ? null : _startListening,
                          child: const Text('Start Listening'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isListening ? _stopListening : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Stop'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${_isListening ? "Listening" : "Stopped"}',
                      style: TextStyle(
                        color: _isListening ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Last action
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Action',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastAction,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Available commands
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Voice Commands',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text('Wake Words: "Hey ReflectifAI", "Wake up"'),
                    const Text(
                      'Actions: "Take note", "Start recording", "Save recording"',
                    ),
                    const Text('Control: "Stop listening", "Pause detection"'),
                    const Text('Navigation: "Open settings", "Show menu"'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action history
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Action History',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child:
                            _actionHistory.isEmpty
                                ? const Center(
                                  child: Text(
                                    'No actions yet.\nStart listening and try saying a command.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: _actionHistory.length,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.mic, size: 16),
                                      title: Text(
                                        _actionHistory[index],
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
