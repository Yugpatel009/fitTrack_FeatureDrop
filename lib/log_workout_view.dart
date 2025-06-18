import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'models.dart'; // Import your data models

class LogWorkoutView extends StatefulWidget {
  const LogWorkoutView({super.key});

  @override
  State<LogWorkoutView> createState() => _LogWorkoutViewState();
}

class _LogWorkoutViewState extends State<LogWorkoutView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _workoutDate = DateTime.now();
  final TextEditingController _sessionDurationController = TextEditingController();

  List<Exercise> _allExercises = []; // All exercises from setup
  List<ScheduledExercise> _dailyScheduledExercises = []; // Exercises for the selected day
  double _userWeightKg = 70.0; // Default weight, will be loaded from profile

  // A complex map to hold TextEditingControllers for each set of each exercise
  // Structure: { exerciseId: [{ 'reps': TextEditingController, 'weight': TextEditingController }, ... ] }
  Map<String, List<Map<String, TextEditingController>>> _exerciseSetControllers = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _sessionDurationController.text = '60'; // Default duration
    _fetchInitialData();
  }

  @override
  void dispose() {
    _sessionDurationController.dispose();
    // Dispose all dynamic controllers
    _exerciseSetControllers.forEach((exerciseId, sets) {
      for (var setMap in sets) {
        setMap['reps']?.dispose();
        setMap['weight']?.dispose();
      }
    });
    super.dispose();
  }

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> _userLogsCollection() {
    return _db.collection('users').doc(currentUser!.uid).collection('logs');
  }

  CollectionReference<Map<String, dynamic>> _userExercisesCollection() {
    return _db.collection('users').doc(currentUser!.uid).collection('exercises');
  }

  DocumentReference<Map<String, dynamic>> _userProfileDocument() {
    return _db.collection('users').doc(currentUser!.uid).collection('profile').doc('info');
  }

  DocumentReference<Map<String, dynamic>> _userScheduleDocument() {
    return _db.collection('users').doc(currentUser!.uid).collection('schedule').doc('weeklyPlan');
  }

  Future<void> _fetchInitialData() async {
    if (currentUser == null) return;

    setState(() { _isLoading = true; });
    try {
      // Fetch user profile for weight
      final profileDoc = await _userProfileDocument().get();
      if (profileDoc.exists && profileDoc.data() != null) {
        // Use UserProfile model to parse data
        _userWeightKg = UserProfile.fromFirestore(profileDoc).weightKg;
      } else {
        _userWeightKg = 70.0; // Fallback
      }

      // Fetch all exercises
      final exercisesSnapshot = await _userExercisesCollection().orderBy("name").get();
      _allExercises = exercisesSnapshot.docs.map((doc) => Exercise.fromFirestore(doc)).toList();

      // Load scheduled exercises for today
      await _loadScheduledExercisesForDate(_workoutDate);
    } catch (e) {
      _showMessage("Error loading initial data: $e");
      debugPrint("Error loading initial data for Log Workout: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadScheduledExercisesForDate(DateTime date) async {
    if (currentUser == null) return;

    setState(() { _isLoading = true; }); // Show loading while fetching schedule
    try {
      final scheduleDoc = await _userScheduleDocument().get();
      Map<String, List<ScheduledExercise>> weeklySchedule = {};
      if (scheduleDoc.exists && scheduleDoc.data() != null) {
        weeklySchedule = (scheduleDoc.data() as Map<String, dynamic>).map((day, exercises) {
          return MapEntry(
            day,
            (exercises as List<dynamic>)
                .map((e) => ScheduledExercise.fromMap(e as Map<String, dynamic>))
                .toList(),
          );
        });
      }

      // Convert selected date to day of week string
      final String dayOfWeek = _getDayOfWeekString(date);
      _dailyScheduledExercises = weeklySchedule[dayOfWeek] ?? [];

      // Initialize controllers for new daily schedule
      _exerciseSetControllers.clear(); // Clear previous controllers
      for (var scheduledEx in _dailyScheduledExercises) {
        _exerciseSetControllers[scheduledEx.exerciseId] = List.generate(
          scheduledEx.sets,
          (_) => {
            'reps': TextEditingController(text: scheduledEx.reps.toString()),
            'weight': TextEditingController(), // Default empty or 0
          },
        );
      }
    } catch (e) {
      _showMessage("Error loading daily schedule: $e");
      debugPrint("Error loading daily schedule for Log Workout: $e");
      _dailyScheduledExercises = [];
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  String _getDayOfWeekString(DateTime date) {
    // Dart's weekday property: Monday is 1, Sunday is 7.
    // HTML's DAYS_OF_WEEK: ["Monday", ..., "Sunday"] maps 0-6
    // Need to adjust for 0-indexed array where Monday is 0 and Sunday is 6
    final List<String> daysOfWeek = [
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ];
    int weekday = date.weekday; // 1 (Mon) - 7 (Sun)
    return daysOfWeek[weekday - 1]; // Convert to 0-6 index
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _workoutDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _workoutDate) {
      setState(() {
        _workoutDate = picked;
      });
      await _loadScheduledExercisesForDate(_workoutDate); // Reload exercises for new date
    }
  }

  Future<void> _saveWorkout() async {
    if (currentUser == null) {
      _showMessage("Please log in to save workout.");
      return;
    }

    final int? sessionDurationMinutes = int.tryParse(_sessionDurationController.text.trim());

    if (sessionDurationMinutes == null || sessionDurationMinutes <= 0) {
      _showMessage("Valid session duration (minutes) required.");
      return;
    }

    List<LoggedExercise> loggedExercises = []; // Changed to use LoggedExercise model
    double totalSessionWeight = 0;
    int totalValidLoggedExercises = 0;
    double totalMetValues = 0;

    for (var scheduledEx in _dailyScheduledExercises) {
      final exercise = _allExercises.firstWhereOrNull((ex) => ex.id == scheduledEx.exerciseId);
      if (exercise == null) continue; // Skip if exercise details not found

      List<LoggedSet> setsData = []; // Changed to use LoggedSet model
      double exerciseTotalWeight = 0;
      int validSetsLogged = 0;

      final controllersForExercise = _exerciseSetControllers[scheduledEx.exerciseId];
      if (controllersForExercise == null) continue;

      for (var setMap in controllersForExercise) {
        final double? reps = double.tryParse(setMap['reps']!.text.trim()); // Changed to double
        final double? weight = double.tryParse(setMap['weight']!.text.trim());

        if (reps != null && reps > 0 && weight != null && weight >= 0) {
          setsData.add(LoggedSet(reps: reps, weight: weight)); // Use LoggedSet
          exerciseTotalWeight += reps * weight;
          validSetsLogged++;
        }
      }

      if (validSetsLogged > 0) {
        loggedExercises.add(
          LoggedExercise(
            exerciseId: scheduledEx.exerciseId,
            name: exercise.name,
            sets: setsData,
            totalWeightLifted: exerciseTotalWeight,
            targetSets: scheduledEx.sets,
            targetReps: scheduledEx.reps,
            met: exercise.met,
          ),
        );
        totalSessionWeight += exerciseTotalWeight;
        totalMetValues += exercise.met;
        totalValidLoggedExercises++;
      }
    }

    if (loggedExercises.isEmpty) {
      _showMessage("No exercises with valid reps/weights logged for this session.");
      return;
    }

    double averageMET = (totalValidLoggedExercises > 0) ? (totalMetValues / totalValidLoggedExercises) : 5.0;
    final double estimatedCaloriesBurned = (averageMET * _userWeightKg * (sessionDurationMinutes / 60));

    // Create WorkoutLog object
    final newLog = WorkoutLog(
      date: DateFormat('yyyy-MM-dd').format(_workoutDate),
      dayOfWeek: _getDayOfWeekString(_workoutDate),
      exercises: loggedExercises, // List of LoggedExercise objects
      totalSessionWeight: totalSessionWeight,
      estimatedCaloriesBurned: double.parse(estimatedCaloriesBurned.toStringAsFixed(1)),
      durationMinutes: sessionDurationMinutes,
    );

    try {
      await _userLogsCollection().add(newLog.toFirestore()); // Save using toFirestore() method

      // Clear duration and reset exercise inputs after saving
      _sessionDurationController.clear();
      await _loadScheduledExercisesForDate(_workoutDate); // Re-initialize controllers
      
      _showMessage(
          "Workout saved! Total: ${totalSessionWeight.toStringAsFixed(0)} kg. Calories: ~${estimatedCaloriesBurned.toStringAsFixed(0)} kcal.");
    } catch (e) {
      _showMessage("Failed to save workout: $e");
      debugPrint("Error saving workout: $e");
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

    // --- START: Added SingleChildScrollView and Padding for scrollability ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0), // Consistent padding as in HTML layout
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log Your Workout',
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
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Select Date:',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              suffixIcon: const Icon(Icons.calendar_today),
                              isDense: true,
                            ),
                            baseStyle: const TextStyle(fontSize: 16, color: Colors.black),
                            child: Text(
                              DateFormat('yyyy-MM-dd').format(_workoutDate),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _sessionDurationController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Duration (mins):',
                            hintText: 'e.g., 60',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _dailyScheduledExercises.isEmpty
                      ? Text(
                          'No exercises scheduled for ${_getDayOfWeekString(_workoutDate)}.',
                          style: const TextStyle(color: Colors.grey),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _dailyScheduledExercises.length,
                          itemBuilder: (context, index) {
                            final scheduledEx = _dailyScheduledExercises[index];
                            final exercise = _allExercises.firstWhereOrNull((ex) => ex.id == scheduledEx.exerciseId);

                            if (exercise == null) {
                              return Card(
                                color: Colors.orange[50],
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    'Warning: Exercise with ID ${scheduledEx.exerciseId} not found in your exercise list. Please update your setup.',
                                    style: const TextStyle(color: Colors.orange),
                                  ),
                                ),
                              );
                            }

                            return _buildExerciseLogItem(exercise, scheduledEx);
                          },
                        ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveWorkout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Save Workout', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    // --- END: Added SingleChildScrollView and Padding for scrollability ---
  }

  Widget _buildExerciseLogItem(Exercise exercise, ScheduledExercise scheduledEx) {
    // Ensure controllers are initialized for this exercise
    if (!_exerciseSetControllers.containsKey(exercise.id)) {
      _exerciseSetControllers[exercise.id] = List.generate(
        scheduledEx.sets,
        (_) => {
          'reps': TextEditingController(text: scheduledEx.reps.toString()),
          'weight': TextEditingController(),
        },
      );
    }
    final List<Map<String, TextEditingController>> sets = _exerciseSetControllers[exercise.id]!;

    return Card(
      color: Colors.grey[50],
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            Text(
              'Target: ${scheduledEx.sets} sets x ${scheduledEx.reps} reps',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scheduledEx.sets,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          'Set ${index + 1}:',
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: sets[index]['reps'],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Reps',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: sets[index]['weight'],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Weight (kg)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}