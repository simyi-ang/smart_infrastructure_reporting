import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Admin Command Dashboard',
          style: TextStyle(
            fontSize: 28,
          ),
        ),
      ),
    );
  }
}