import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart'; // For picking files
import 'package:path_provider/path_provider.dart'; // For temporary directory
import 'dart:io'; // For File operations
import 'dart:convert'; // For JSON encoding/decoding
import 'package:permission_handler/permission_handler.dart'; // For storage permissions
import 'package:intl/intl.dart'; // For date formatting

import 'models.dart'; // Import your data models

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _userWeightController = TextEditingController();
  UserProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _userWeightController.dispose();
    super.dispose();
  }

  User? get currentUser => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> _userProfileDocument() {
    return _db.collection('users').doc(currentUser!.uid).collection('profile').doc('info');
  }

  CollectionReference<Map<String, dynamic>> _userExercisesCollection() {
    return _db.collection('users').doc(currentUser!.uid).collection('exercises');
  }

  DocumentReference<Map<String, dynamic>> _userScheduleDocument() {
    return _db.collection('users').doc(currentUser!.uid).collection('schedule').doc('weeklyPlan');
  }

  CollectionReference<Map<String, dynamic>> _userLogsCollection() {
    return _db.collection('users').doc(currentUser!.uid).collection('logs');
  }

  Future<void> _fetchUserProfile() async {
    if (currentUser == null) {
      _showMessage("No user logged in.");
      setState(() { _isLoading = false; });
      return;
    }

    setState(() { _isLoading = true; });
    try {
      final doc = await _userProfileDocument().get();
      if (doc.exists && doc.data() != null) {
        _userProfile = UserProfile.fromFirestore(doc);
      } else {
        // If profile doesn't exist, create a default one
        _userProfile = UserProfile(email: currentUser!.email, weightKg: 70.0);
        await _userProfileDocument().set(_userProfile!.toFirestore());
      }
      _userWeightController.text = _userProfile!.weightKg.toString();
    } catch (e) {
      _showMessage("Error loading user profile: $e");
      debugPrint("Error loading user profile: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _saveUserProfile() async {
    if (currentUser == null) {
      _showMessage("Please log in to save profile.");
      return;
    }
    final double? weight = double.tryParse(_userWeightController.text.trim());

    if (weight == null || weight <= 0) {
      _showMessage("Valid weight required.");
      return;
    }

    setState(() { _isLoading = true; });
    try {
      _userProfile = UserProfile(email: currentUser!.email, weightKg: weight);
      await _userProfileDocument().set(_userProfile!.toFirestore(), SetOptions(merge: true));
      _showMessage("Profile saved successfully!");
    } catch (e) {
      _showMessage("Failed to save profile: $e");
      debugPrint("Error saving profile: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _exportUserData() async {
    if (currentUser == null) {
      _showMessage("Please log in to export data.");
      return;
    }

    _showMessage("Exporting data... this may take a moment.");
    try {
      // Request storage permission if on a platform that needs it
      if (Platform.isAndroid || Platform.isIOS) {
        var status = await Permission.storage.request();
        if (status.isDenied) {
          _showMessage("Storage permission denied. Cannot export data.");
          return;
        }
      }

      final exercisesSnapshot = await _userExercisesCollection().get();
      final userExercises = exercisesSnapshot.docs.map((doc) => Exercise.fromFirestore(doc).toFirestore()).toList();

      final scheduleDoc = await _userScheduleDocument().get();
      final userSchedule = scheduleDoc.exists ? (scheduleDoc.data() as Map<String, dynamic>?) : {};

      final logsSnapshot = await _userLogsCollection().get();
      final userLogs = logsSnapshot.docs.map((doc) => WorkoutLog.fromFirestore(doc).toFirestore()).toList();
      
      final profileDoc = await _userProfileDocument().get();
      final userProfileData = profileDoc.exists ? (UserProfile.fromFirestore(profileDoc).toFirestore()) : {};

      final dataToExport = {
        'userProfile': userProfileData,
        'exercises': userExercises,
        'schedule': userSchedule,
        'logs': userLogs,
        'exportDate': DateTime.now().toIso8601String(),
      };

      final String jsonData = jsonEncode(dataToExport);

      // Determine where to save the file
      final directory = await getTemporaryDirectory(); // For temporary storage
      final String filePath = '${directory.path}/fittrack_data_${currentUser!.uid}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
      final File file = File(filePath);
      await file.writeAsString(jsonData);

      // Offer to share/download the file
      // For web, this will automatically download. For mobile, it will save.
      // A more robust solution for mobile would involve `share_plus` or similar.
      _showMessage("Data exported to $filePath !");
      debugPrint("Data exported to: $filePath");

    } catch (e) {
      _showMessage("Failed to export data: $e");
      debugPrint("Error exporting data: $e");
    }
  }

  Future<void> _importUserData() async {
    if (currentUser == null) {
      _showMessage("Please log in to import data.");
      return;
    }

    final bool? confirmImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Data Import'),
        content: const Text('This will overwrite your existing data with the content of the selected file. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmImport != true) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        _showMessage("No file selected for import.");
        return;
      }

      final String? filePath = result.files.single.path;
      if (filePath == null) {
        _showMessage("Could not get file path.");
        return;
      }

      final File file = File(filePath);
      final String fileContent = await file.readAsString();
      final Map<String, dynamic> importedData = jsonDecode(fileContent);

      _showMessage("Importing data... This may take a moment.");

      WriteBatch batch = _db.batch();

      // Import User Profile
      if (importedData['userProfile'] != null) {
        batch.set(_userProfileDocument(), importedData['userProfile'], SetOptions(merge: true));
      }

      // Clear existing Exercises and import new ones
      final currentExercises = await _userExercisesCollection().get();
      for (var doc in currentExercises.docs) {
        batch.delete(doc.reference);
      }
      if (importedData['exercises'] != null && importedData['exercises'] is List) {
        for (var exData in importedData['exercises']) {
          batch.set(_userExercisesCollection().doc(), exData as Map<String, dynamic>);
        }
      }

      // Import Schedule
      if (importedData['schedule'] != null) {
        batch.set(_userScheduleDocument(), importedData['schedule']);
      }

      // Clear existing Logs and import new ones
      final currentLogs = await _userLogsCollection().get();
      for (var doc in currentLogs.docs) {
        batch.delete(doc.reference);
      }
      if (importedData['logs'] != null && importedData['logs'] is List) {
        for (var logData in importedData['logs']) {
          batch.set(_userLogsCollection().doc(), logData as Map<String, dynamic>);
        }
      }

      await batch.commit();
      _showMessage("Data imported successfully! Please restart the app to see changes.");
      // For a full refresh, might need to navigate to auth and re-login or rebuild
      // Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthView()), (Route<dynamic> route) => false);

    } catch (e) {
      _showMessage("Failed to import data: $e");
      debugPrint("Error importing data: $e");
    }
  }

  Future<void> _confirmClearUserAccountData() async {
    if (currentUser == null) {
      _showMessage("Please log in.");
      return;
    }

    final TextEditingController _deleteConfirmController = TextEditingController();

    final String? confirmationText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DANGER: Delete ALL Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will delete ALL your exercises, schedule, logs, and profile data from this account. This action cannot be undone. To confirm, type "DELETE" into the box below:'),
            const SizedBox(height: 16),
            TextField(
              controller: _deleteConfirmController,
              decoration: const InputDecoration(
                hintText: 'Type DELETE here',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Pop with null
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_deleteConfirmController.text == 'DELETE') {
                Navigator.of(context).pop('DELETE');
              } else {
                _showMessage("Incorrect confirmation text.");
                // Keep dialog open, or pop with null
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );

    if (confirmationText != 'DELETE') {
      _showMessage("Data deletion cancelled.");
      return;
    }

    setState(() { _isLoading = true; });
    _showMessage("Deleting all your account data... This may take a moment.");
    try {
      WriteBatch batch = _db.batch();

      // Delete profile and schedule documents directly
      batch.delete(_userProfileDocument());
      batch.delete(_userScheduleDocument());

      // Delete all documents in subcollections (exercises and logs)
      final exercisesSnapshot = await _userExercisesCollection().get();
      for (var doc in exercisesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      final logsSnapshot = await _userLogsCollection().get();
      for (var doc in logsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _showMessage("All your account data has been deleted. Logging out...");
      await _auth.signOut(); // Log out after clearing data

    } catch (e) {
      _showMessage("Failed to clear all data: $e");
      debugPrint("Error clearing user data: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500), // Max width similar to HTML's max-w-md
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Email: ${currentUser?.email ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _userWeightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Your Weight (kg):',
                          hintText: 'e.g., 70',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveUserProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Save Profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32), // mt-8
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Management (For Your Account)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _exportUserData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Export My Data'),
                        ),
                      ),
                      const SizedBox(height: 16), // mb-2 and mt-2 combined
                      const Text(
                        'Import Data (JSON to your account):',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _importUserData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Import Data'),
                        ),
                      ),
                      const SizedBox(height: 32), // mt-6
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmClearUserAccountData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Clear All My Account Data'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}