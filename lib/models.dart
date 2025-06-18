import 'package:cloud_firestore/cloud_firestore.dart';

class Exercise {
  final String id;
  String name;
  double met;

  Exercise({required this.id, required this.name, required this.met});

  factory Exercise.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Exercise(
      id: doc.id,
      name: data['name'] ?? '',
      met: (data['met'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'met': met,
    };
  }
}

class ScheduledExercise {
  final String exerciseId;
  int sets;
  int reps;

  ScheduledExercise({required this.exerciseId, required this.sets, required this.reps});

  // Convert from Firestore map
  factory ScheduledExercise.fromMap(Map<String, dynamic> data) {
    return ScheduledExercise(
      exerciseId: data['exerciseId'] ?? '',
      sets: data['sets'] ?? 0,
      reps: data['reps'] ?? 0,
    );
  }

  // Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'sets': sets,
      'reps': reps,
    };
  }
}

// Data model for a logged set within a workout (used in LogWorkoutView)
class LoggedSet {
  final double reps; // Changed to double for consistency, though often int
  final double weight;

  LoggedSet({required this.reps, required this.weight});

  factory LoggedSet.fromMap(Map<String, dynamic> data) {
    return LoggedSet(
      reps: (data['reps'] ?? 0.0).toDouble(),
      weight: (data['weight'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reps': reps,
      'weight': weight,
    };
  }
}

// Data model for a logged exercise within a workout (used in LogWorkoutView)
class LoggedExercise {
  final String exerciseId;
  final String name; // Storing name for easier display/dashboard without re-fetching exercise details
  final List<LoggedSet> sets;
  final double totalWeightLifted;
  final int targetSets; // From scheduled exercise
  final int targetReps; // From scheduled exercise
  final double met; // From exercise details

  LoggedExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.totalWeightLifted,
    required this.targetSets,
    required this.targetReps,
    required this.met,
  });

  factory LoggedExercise.fromMap(Map<String, dynamic> data) {
    return LoggedExercise(
      exerciseId: data['exerciseId'] ?? '',
      name: data['name'] ?? '',
      sets: (data['sets'] as List<dynamic>?)
              ?.map((s) => LoggedSet.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      totalWeightLifted: (data['totalWeightLifted'] ?? 0.0).toDouble(),
      targetSets: data['targetSets'] ?? 0,
      targetReps: data['targetReps'] ?? 0,
      met: (data['met'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'name': name,
      'sets': sets.map((s) => s.toMap()).toList(),
      'totalWeightLifted': totalWeightLifted,
      'targetSets': targetSets,
      'targetReps': targetReps,
      'met': met,
    };
  }
}

// Data model for a full workout log (used in LogWorkoutView and DashboardView)
class WorkoutLog {
  final String? id; // Null for new logs before saving to Firestore
  final String date;
  final String dayOfWeek;
  final List<LoggedExercise> exercises;
  final double totalSessionWeight;
  final double estimatedCaloriesBurned;
  final int durationMinutes;
  final Timestamp? timestamp; // Firestore server timestamp

  WorkoutLog({
    this.id,
    required this.date,
    required this.dayOfWeek,
    required this.exercises,
    required this.totalSessionWeight,
    required this.estimatedCaloriesBurned,
    required this.durationMinutes,
    this.timestamp,
  });

  factory WorkoutLog.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return WorkoutLog(
      id: doc.id,
      date: data['date'] ?? '',
      dayOfWeek: data['dayOfWeek'] ?? '',
      exercises: (data['exercises'] as List<dynamic>?)
              ?.map((e) => LoggedExercise.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalSessionWeight: (data['totalSessionWeight'] ?? 0.0).toDouble(),
      estimatedCaloriesBurned: (data['estimatedCaloriesBurned'] ?? 0.0).toDouble(),
      durationMinutes: data['durationMinutes'] ?? 0,
      timestamp: data['timestamp'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'dayOfWeek': dayOfWeek,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'totalSessionWeight': totalSessionWeight,
      'estimatedCaloriesBurned': estimatedCaloriesBurned,
      'durationMinutes': durationMinutes,
      'timestamp': FieldValue.serverTimestamp(), // Always update timestamp on save
    };
  }
}

// Data model for user profile (used in AuthView, LogWorkoutView, ProfileView)
class UserProfile {
  final String? email;
  double weightKg;

  UserProfile({this.email, required this.weightKg});

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      email: data['email'],
      weightKg: (data['weightKg'] ?? 70.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'weightKg': weightKg,
    };
  }
}


// Extension to help find exercise by ID (similar to Array.prototype.find in JS)
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}