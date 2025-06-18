import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart'; // Import the new models file

class SetupView extends StatefulWidget {
  const SetupView({super.key});

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Exercise> _exercises = [];
  Map<String, List<ScheduledExercise>> _weeklySchedule = {};
  bool _isLoading = true;

  final TextEditingController _exerciseNameController = TextEditingController();
  final TextEditingController _exerciseMetController = TextEditingController();

  // For modals
  final TextEditingController _modalSetsController = TextEditingController();
  final TextEditingController _modalRepsController = TextEditingController();
  String? _selectedExerciseIdForModal; // For adding to schedule
  String? _modalDayName;

  final List<String> _daysOfWeek = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _exerciseNameController.dispose();
    _exerciseMetController.dispose();
    _modalSetsController.dispose();
    _modalRepsController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() { _isLoading = true; });
    await _fetchExercises();
    await _fetchSchedule();
    setState(() { _isLoading = false; });
  }

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> _userExercisesCollection() {
    return _db.collection('users').doc(currentUser!.uid).collection('exercises');
  }

  DocumentReference<Map<String, dynamic>> _userScheduleDocument() {
    return _db.collection('users').doc(currentUser!.uid).collection('schedule').doc('weeklyPlan');
  }

  // --- Exercise Management (Firestore & Local State) ---

  Future<void> _fetchExercises() async {
    if (currentUser == null) return;
    try {
      final snapshot = await _userExercisesCollection().orderBy("name").get();
      setState(() {
        _exercises = snapshot.docs.map((doc) => Exercise.fromFirestore(doc)).toList();
      });
    } catch (e) {
      _showMessage("Error fetching exercises: $e");
      debugPrint("Error fetching exercises: $e");
    }
  }

  Future<void> _addExercise() async {
    if (currentUser == null) {
      _showMessage("Please log in to add exercises.");
      return;
    }
    final name = _exerciseNameController.text.trim();
    final met = double.tryParse(_exerciseMetController.text.trim());

    if (name.isEmpty || met == null || met <= 0) {
      _showMessage("Valid exercise name and MET value required.");
      return;
    }
    if (_exercises.any((ex) => ex.name.toLowerCase() == name.toLowerCase())) {
      _showMessage("Exercise with this name already exists.");
      return;
    }

    try {
      final docRef = await _userExercisesCollection().add(Exercise(id: '', name: name, met: met).toFirestore());
      setState(() {
        _exercises.add(Exercise(id: docRef.id, name: name, met: met));
        _exercises.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
      _exerciseNameController.clear();
      _exerciseMetController.clear();
      _showMessage("Exercise added successfully!");
    } catch (e) {
      _showMessage("Failed to add exercise: $e");
      debugPrint("Error adding exercise: $e");
    }
  }

  Future<void> _updateExercise(Exercise exercise) async {
    if (currentUser == null) {
      _showMessage("Please log in.");
      return;
    }
    try {
      await _userExercisesCollection().doc(exercise.id).update(exercise.toFirestore());
      setState(() {
        final index = _exercises.indexWhere((ex) => ex.id == exercise.id);
        if (index != -1) {
          _exercises[index] = exercise;
          _exercises.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }
      });
      _showMessage("Exercise updated successfully!");
    } catch (e) {
      _showMessage("Failed to update exercise: $e");
      debugPrint("Error updating exercise: $e");
    }
  }

  Future<void> _deleteExercise(String exerciseId) async {
    if (currentUser == null) {
      _showMessage("Please log in.");
      return;
    }
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this exercise? It will also be removed from your weekly schedule.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    try {
      // Delete from exercises collection
      await _userExercisesCollection().doc(exerciseId).delete();

      // Remove from local state
      setState(() {
        _exercises.removeWhere((ex) => ex.id == exerciseId);
      });

      // Remove from schedule in Firestore and local state
      for (var day in _daysOfWeek) {
        if (_weeklySchedule.containsKey(day)) {
          _weeklySchedule[day]!.removeWhere((item) => item.exerciseId == exerciseId);
        }
      }
      await _userScheduleDocument().set(
        _weeklySchedule.map((key, value) => MapEntry(key, value.map((e) => e.toMap()).toList())),
      );

      setState(() {
        // Trigger re-render of schedule as well
      });
      _showMessage("Exercise deleted successfully.");
    } catch (e) {
      _showMessage("Failed to delete exercise: $e");
      debugPrint("Error deleting exercise: $e");
    }
  }

  // --- Schedule Management (Firestore & Local State) ---

  Future<void> _fetchSchedule() async {
    if (currentUser == null) return;
    try {
      final doc = await _userScheduleDocument().get();
      setState(() {
        if (doc.exists && doc.data() != null) {
          _weeklySchedule = (doc.data() as Map<String, dynamic>).map((day, exercises) {
            return MapEntry(
              day,
              (exercises as List<dynamic>)
                  .map((e) => ScheduledExercise.fromMap(e as Map<String, dynamic>))
                  .toList(),
            );
          });
        } else {
          // Initialize empty schedule for all days if document doesn't exist
          for (var day in _daysOfWeek) {
            _weeklySchedule[day] = [];
          }
        }
      });
    } catch (e) {
      _showMessage("Error fetching schedule: $e");
      debugPrint("Error fetching schedule: $e");
      for (var day in _daysOfWeek) {
        _weeklySchedule[day] = []; // Ensure schedule is initialized even on error
      }
    }
  }

  Future<void> _saveScheduleToFirestore() async {
    if (currentUser == null) return;
    try {
      await _userScheduleDocument().set(
        _weeklySchedule.map((key, value) => MapEntry(key, value.map((e) => e.toMap()).toList())),
      );
      _showMessage("Schedule updated!");
    } catch (e) {
      _showMessage("Failed to save schedule: $e");
      debugPrint("Error saving schedule: $e");
    }
  }

  Future<void> _addScheduledExercise() async {
    if (_selectedExerciseIdForModal == null) {
      _showMessage("Please select an exercise.");
      return;
    }
    final sets = int.tryParse(_modalSetsController.text.trim());
    final reps = int.tryParse(_modalRepsController.text.trim());

    if (sets == null || sets <= 0 || reps == null || reps <= 0) {
      _showMessage("Enter valid sets and reps.");
      return;
    }
    if (_modalDayName == null || !_daysOfWeek.contains(_modalDayName)) {
      _showMessage("Invalid day selected for schedule.");
      return;
    }

    final newScheduledItem = ScheduledExercise(
      exerciseId: _selectedExerciseIdForModal!,
      sets: sets,
      reps: reps,
    );

    setState(() {
      _weeklySchedule[_modalDayName!]!.add(newScheduledItem);
    });
    Navigator.of(context).pop(); // Close the modal
    await _saveScheduleToFirestore();
  }

  Future<void> _removeScheduledExercise(String day, int index) async {
    if (currentUser == null) return;
    setState(() {
      _weeklySchedule[day]?.removeAt(index);
    });
    await _saveScheduleToFirestore();
    _showMessage("Exercise removed from schedule.");
  }

  void _reorderScheduledExercises(String day, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _weeklySchedule[day]!.removeAt(oldIndex);
    _weeklySchedule[day]!.insert(newIndex, item);
    _saveScheduleToFirestore(); // Save reordered schedule to Firestore
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workout Plan Setup',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.indigo,
            tabs: const [
              Tab(text: 'Manage Exercises'),
              Tab(text: 'Weekly Schedule'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildManageExercisesTab(),
              _buildWeeklyScheduleTab(),
            ],
          ),
        ),
      ],
    );
  }

  // --- Manage Exercises Tab UI ---
  Widget _buildManageExercisesTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Exercise',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _exerciseNameController,
                    decoration: InputDecoration(
                      labelText: 'Exercise Name (e.g., Bench Press)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _exerciseMetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'MET Value (e.g., 5.0)',
                      hintText: 'e.g., 5.0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addExercise,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Add Exercise'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Exercises',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _exercises.isEmpty
                      ? const Text('No exercises added yet.', style: TextStyle(color: Colors.grey))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _exercises.length,
                          itemBuilder: (context, index) {
                            final exercise = _exercises[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildExerciseListItem(exercise),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseListItem(Exercise exercise) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${exercise.name} (MET: ${exercise.met})',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _openEditExerciseModal(exercise),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Edit', style: TextStyle(color: Colors.blue, fontSize: 14)),
              ),
              TextButton(
                onPressed: () => _deleteExercise(exercise.id),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEditExerciseModal(Exercise exercise) {
    final TextEditingController editNameController = TextEditingController(text: exercise.name);
    final TextEditingController editMetController = TextEditingController(text: exercise.met.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editNameController,
              decoration: const InputDecoration(labelText: 'Exercise Name'),
            ),
            TextField(
              controller: editMetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'MET Value'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = editNameController.text.trim();
              final newMet = double.tryParse(editMetController.text.trim());

              if (newName.isEmpty || newMet == null || newMet <= 0) {
                _showMessage("Valid exercise name and MET value required.");
                return;
              }
              if (_exercises.any((ex) => ex.id != exercise.id && ex.name.toLowerCase() == newName.toLowerCase())) {
                _showMessage("Another exercise with this name already exists.");
                return;
              }

              exercise.name = newName;
              exercise.met = newMet;
              _updateExercise(exercise);
              Navigator.of(context).pop();
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // --- Weekly Schedule Tab UI ---
  Widget _buildWeeklyScheduleTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set Weekly Schedule',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : MediaQuery.of(context).size.width > 600 ? 2 : 1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2, // Adjust as needed
                    ),
                    itemCount: _daysOfWeek.length,
                    itemBuilder: (context, index) {
                      final day = _daysOfWeek[index];
                      return _buildDayScheduleCard(day);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayScheduleCard(String day) {
    return Card(
      color: Colors.grey[50],
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              day,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), // Important for nested scrollables
                onReorder: (oldIndex, newIndex) => _reorderScheduledExercises(day, oldIndex, newIndex),
                children: [
                  if (_weeklySchedule[day]?.isEmpty ?? true)
                    _buildEmptySchedulePlaceholder(day)
                  else
                    ..._weeklySchedule[day]!.asMap().entries.map((entry) {
                      int index = entry.key;
                      ScheduledExercise item = entry.value;
                      final exercise = _exercises.firstWhereOrNull((ex) => ex.id == item.exerciseId);

                      return Dismissible(
                        key: ValueKey('${day}_${item.exerciseId}_$index'), // Unique key for Dismissible
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          _removeScheduledExercise(day, index);
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: _buildScheduledExerciseListItem(exercise, item, day, index),
                      );
                    }).toList(),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openAddExerciseToDayModal(day),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add Exercise to $day', style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySchedulePlaceholder(String day) {
    return Container(
      key: ValueKey('placeholder_$day'), // Key for ReorderableListView
      height: 40, // Provide some height for droppable area
      alignment: Alignment.center,
      child: const Text(
        'No exercises scheduled. Drag or add one!',
        style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildScheduledExerciseListItem(Exercise? exercise, ScheduledExercise item, String day, int index) {
    return Card(
      key: ValueKey('${day}_${item.exerciseId}_$index'), // Key for ReorderableListView
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                exercise != null
                    ? '${exercise.name} (${item.sets}s x ${item.reps}r)'
                    : 'Unknown Exercise (ID: ${item.exerciseId})',
                style: TextStyle(
                  fontSize: 14,
                  color: exercise != null ? Colors.black87 : Colors.grey,
                  fontStyle: exercise != null ? FontStyle.normal : FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.drag_handle, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }


  void _openAddExerciseToDayModal(String day) {
    _modalDayName = day;
    _selectedExerciseIdForModal = null; // Reset selection
    _modalSetsController.text = '3';
    _modalRepsController.text = '10';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Exercise to $day'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Exercise',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: _selectedExerciseIdForModal,
              hint: const Text('-- Select Exercise --'),
              items: _exercises.map((ex) {
                return DropdownMenuItem(
                  value: ex.id,
                  child: Text(ex.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedExerciseIdForModal = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modalSetsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Sets',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modalRepsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Reps per Set',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addScheduledExercise,
            child: const Text('Add to Day'),
          ),
        ],
      ),
    );
  }
}