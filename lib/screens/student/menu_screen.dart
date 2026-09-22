import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Menu'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.wb_sunny),
            title: Text('Monday'),
            subtitle: Text('Breakfast • Lunch • Dinner'),
          ),
          ListTile(
            leading: Icon(Icons.wb_sunny),
            title: Text('Tuesday'),
            subtitle: Text('Breakfast • Lunch • Dinner'),
          ),
          ListTile(
            leading: Icon(Icons.wb_sunny),
            title: Text('Wednesday'),
            subtitle: Text('Breakfast • Lunch • Dinner'),
          ),
          ListTile(
            leading: Icon(Icons.wb_sunny),
            title: Text('Thursday'),
            subtitle: Text('Breakfast • Lunch • Dinner'),
          ),
          ListTile(
            leading: Icon(Icons.wb_sunny),
            title: Text('Friday'),
            subtitle: Text('Breakfast • Lunch • Dinner'),
          ),
          ListTile(
            leading: Icon(Icons.wb_sunny),
            title: Text('Saturday'),
            subtitle: Text('Breakfast • Lunch • Dinner'),
          ),
          ListTile(
            leading: Icon(Icons.wb_sunny),
            title: Text('Sunday'),
            subtitle: Text('Breakfast • Lunch • Dinner'),
          ),
        ],
      ),
    );
  }
}