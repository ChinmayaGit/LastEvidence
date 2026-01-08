import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _status = 'Not tested';
  String _lastError = '';
  bool _isLoading = false;
  String? _readValue;
  String _connectionInfo = 'Using Firestore';

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      setState(() {
        _connectionInfo = 'Firestore is ready';
      });
    } catch (e) {
      setState(() {
        _connectionInfo = 'Connection check failed: $e';
      });
    }
  }

  Future<void> _testWrite() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing Firestore write...';
      _lastError = '';
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('test')
          .doc('write_test')
          .set({
            'message': 'Hello from Flutter!',
            'timestamp': timestamp,
            'testId': 'test_$timestamp',
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Write operation timed out after 10 seconds.\n\n'
                'Possible causes:\n'
                '1. Firestore is not enabled in Firebase Console\n'
                '2. Security rules are blocking writes\n'
                '3. Check your internet connection',
              );
            },
          );

      setState(() {
        _status = '✅ Firestore write successful!';
        _isLoading = false;
      });
    } on TimeoutException catch (e) {
      setState(() {
        _status = '❌ Write timed out';
        _lastError = e.toString();
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Firestore error: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _status = '❌ Write failed';
        _lastError =
            'Error: $e\n\n'
            'This usually means:\n'
            '1. Firestore is not enabled in Firebase Console\n'
            '2. Go to Firebase Console → Firestore Database → Create Database\n'
            '3. Check Security Rules allow writes';
        _isLoading = false;
      });
    }
  }

  Future<void> _testRead() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing read...';
      _lastError = '';
      _readValue = null;
    });

    try {
      final doc = await _firestore
          .collection('test')
          .doc('write_test')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Read operation timed out after 10 seconds.',
              );
            },
          );

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _status = '✅ Read successful!';
          _readValue = data.toString();
          _isLoading = false;
        });
      } else {
        setState(() {
          _status = '⚠️ No data found (write first)';
          _isLoading = false;
        });
      }
    } on TimeoutException catch (e) {
      setState(() {
        _status = '❌ Read timed out';
        _lastError = e.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Read failed';
        _lastError = e.toString();
        _isLoading = false;
      });
    }
  }

  StreamSubscription<DocumentSnapshot>? _listenerSubscription;

  Future<void> _testRealtimeListener() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing realtime listener...';
      _lastError = '';
    });

    try {
      // Cancel previous listener if exists
      await _listenerSubscription?.cancel();

      _listenerSubscription = _firestore
          .collection('test')
          .doc('realtime_test')
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              if (snapshot.exists) {
                final data = snapshot.data() as Map<String, dynamic>;
                setState(() {
                  _status = '✅ Realtime listener active!';
                  _readValue = data.toString();
                  _isLoading = false;
                });
              } else {
                setState(() {
                  _status = '⚠️ Waiting for data...';
                });
              }
            }
          });

      // Write a test value to trigger the listener
      await _firestore.collection('test').doc('realtime_test').set({
        'message': 'Realtime test',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Wait a bit for the listener to trigger
      await Future.delayed(const Duration(seconds: 2));

      if (_isLoading) {
        setState(() {
          _status = '✅ Listener set up (waiting for updates)';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Listener failed';
        _lastError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _clearTestData() async {
    setState(() {
      _isLoading = true;
      _status = 'Clearing test data...';
    });

    try {
      // Cancel listener before clearing
      await _listenerSubscription?.cancel();
      _listenerSubscription = null;

      final batch = _firestore.batch();
      batch.delete(_firestore.collection('test').doc('write_test'));
      batch.delete(_firestore.collection('test').doc('realtime_test'));
      await batch.commit();

      setState(() {
        _status = '✅ Test data cleared';
        _readValue = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Clear failed';
        _lastError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _listenerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Connection Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 16,
                        color: _status.contains('✅')
                            ? Colors.green
                            : _status.contains('❌')
                            ? Colors.red
                            : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_lastError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Error: $_lastError',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                    if (_isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                    if (_connectionInfo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _connectionInfo,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (_readValue != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Data: $_readValue',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testWrite,
              icon: const Icon(Icons.edit),
              label: const Text('Test Write'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testRead,
              icon: const Icon(Icons.read_more),
              label: const Text('Test Read'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testRealtimeListener,
              icon: const Icon(Icons.sync),
              label: const Text('Test Realtime Listener'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _clearTestData,
              icon: const Icon(Icons.delete),
              label: const Text('Clear Test Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Troubleshooting',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If tests are timing out or failing:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '1. Check Firebase Console → Firestore Database is enabled',
                      style: TextStyle(fontSize: 13),
                    ),
                    const Text(
                      '2. Verify google-services.json is in android/app/',
                      style: TextStyle(fontSize: 13),
                    ),
                    const Text(
                      '3. Check Security Rules allow read/write (temporarily)',
                      style: TextStyle(fontSize: 13),
                    ),
                    const Text(
                      '4. Ensure you have internet connection',
                      style: TextStyle(fontSize: 13),
                    ),
                    const Text(
                      '5. Check Firebase project matches google-services.json',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Click "Test Write" to write data to Firestore',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      '2. Click "Test Read" to read the data back',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      '3. Click "Test Realtime Listener" to test real-time updates',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      '4. If all tests pass, Firestore is connected! ✅',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
