import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// You'll create these views later
import 'dashboard_view.dart';
import 'log_workout_view.dart';
import 'profile_view.dart';
import 'setup_view.dart';


class AppContainer extends StatefulWidget {
  const AppContainer({super.key});

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer> {
  int _selectedIndex = 0; // Current index for navigation

  static final List<Widget> _widgetOptions = <Widget>[
    const SetupView(),      // Corresponds to 'Setup Plan'
    const LogWorkoutView(), // Corresponds to 'Log Workout'
    const DashboardView(),  // Corresponds to 'Dashboard'
    const ProfileView(),    // Corresponds to 'User Profile'
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitTrack'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                user?.email ?? 'N/A',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.indigo)),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar for larger screens
          if (MediaQuery.of(context).size.width >= 768) // md breakpoint
            NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.settings),
                  label: Text('Setup Plan'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.fitness_center),
                  label: Text('Log Workout'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person),
                  label: Text('User Profile'),
                ),
              ],
            ),
          
          // Main content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _widgetOptions.elementAt(_selectedIndex),
            ),
          ),
        ],
      ),
      // Bottom navigation bar for smaller screens
      bottomNavigationBar: MediaQuery.of(context).size.width < 768
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Colors.indigo,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed, // Important for more than 3 items
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Setup',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.fitness_center),
                  label: 'Log',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            )
          : null, // No bottom nav if on desktop/tablet
    );
  }
}