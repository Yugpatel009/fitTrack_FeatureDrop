import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
// Make sure to generate this file after running 'flutterfire configure'
import 'firebase_options.dart'; 

// Import your views (you'll create these later)
import 'auth_view.dart'; // For login/signup
import 'app_container.dart'; // For the main app content (dashboard, setup, log workout)

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized
  await Firebase.initializeApp( // Initialize Firebase
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FitTrackApp());
}

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTrack',
      theme: ThemeData(
        primarySwatch: Colors.indigo, // Primary color for the app
        fontFamily: 'Inter', // Assuming you'll add Inter font later
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        // Further customize your theme to match Tailwind/Inter styles
        scaffoldBackgroundColor: const Color(0xFFF0F2F5), // Corresponds to #f0f2f5
      ),
      home: StreamBuilder<User?>(
        // Listen to Firebase Auth state changes
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show a loading indicator while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          // If user is logged in, show the main app container
          if (snapshot.hasData && snapshot.data != null) {
            return const AppContainer(); // Your main app content
          }
          // If no user is logged in, show the authentication view
          return const AuthView(); // Your login/signup view
        },
      ),
    );
  }
}