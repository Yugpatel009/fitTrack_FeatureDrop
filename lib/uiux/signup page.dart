import 'package:flutter/material.dart';
import 'package:untitled/loginpage.dart';

class Sign extends StatefulWidget {
  final String title;

  const Sign({super.key, required this.title});

  @override
  State<Sign> createState() => _SignState();
}

class _SignState extends State<Sign> {
  bool isChecked = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final fieldWidth = isMobile ? screenWidth * 0.85 : 400.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                const Text(
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 100),

                // Name Field
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Full Name or Username',
                      hintText: 'Enter your Name Or Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.cyan),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.cyan, width: 2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Email Field
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.cyan),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.cyan, width: 2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Password Field
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your Password',
                      suffixIcon: Icon(Icons.remove_red_eye),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.cyan),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.cyan, width: 2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Confirm Password
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Enter your Password again',
                      suffixIcon: Icon(Icons.remove_red_eye),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.cyan),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.cyan, width: 2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Terms and Conditions
                SizedBox(
                  width: fieldWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            isChecked = value!;
                          });
                        },
                      ),
                      Expanded(
                        child: Wrap(
                          children: [
                            const Text("I agree to the ", style: TextStyle(color: Colors.black)),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                'Terms & Conditions',
                                style: TextStyle(
                                  color: Colors.green,

                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Login Button
                SizedBox(
                  width: fieldWidth,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                      shadowColor: Colors.grey,
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),



                const SizedBox(height: 15),

                // Bottom Sign Up Link
                SizedBox(
                  width: fieldWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account?", style: TextStyle(color: Colors.black)),
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Login(title: 'Flutter Demo Home Page'),
                            ),
                          );
                        },
                        child: Text(
                          'Log In',
                          style: TextStyle(
                            color: Colors.green,

                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}