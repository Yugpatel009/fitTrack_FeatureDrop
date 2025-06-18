import 'package:flutter/material.dart';
import 'package:untitled/signup%20page.dart';

class Login extends StatelessWidget {
  final String title;

  const Login({super.key, required this.title});

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
                // Title
                const SizedBox(height: 30),
                const Text(
                  "Fit Track",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 100),

                // Email Field
                Container(
                  width: fieldWidth,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Email or Username',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email),
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
                Container(
                  width: fieldWidth,
                  child: TextField(
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Password (PIN)',
                      hintText: 'Enter your PIN',
                      prefixIcon: Icon(Icons.lock),
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

                // Forgot Password
                Container(
                  width: fieldWidth,
                  alignment: Alignment.centerRight,
                  child:InkWell(
                    onTap: () {
                      print("Link tapped");
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.green,

                      ),
                    ),
                  )
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
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // OR Divider
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Expanded(
                      child: Divider(
                        color: Colors.grey,
                        thickness: 1,
                        indent: 40,
                        endIndent: 10,
                      ),
                    ),
                    Text('or', style: TextStyle(fontSize: 20)),
                    Expanded(
                      child: Divider(
                        color: Colors.grey,
                        thickness: 1,
                        indent: 10,
                        endIndent: 40,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),
                TextButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(

                    padding: const EdgeInsets.symmetric(horizontal: 110,vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: Colors.grey
                      )
                    ),


                  ),
                  child: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(height: 20,),
                TextButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(

                    padding: const EdgeInsets.symmetric(horizontal: 110,vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: Colors.grey
                      )
                    ),


                  ),
                  child: const Text(
                    'Continue with Github',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(height: 15,),
                Container(
                  width: fieldWidth,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(left:  100),
                  child: Row(
                    children: [
                      Text("Don't have an account?",style: TextStyle(color:Colors.black),),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Sign(title: 'Flutter Demo Home Page'),
                            ),
                          );
                        },
                        child: Text(
                          'Sign Up',
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
