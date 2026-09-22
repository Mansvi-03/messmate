import 'package:flutter/material.dart';

class MenuManagement extends StatefulWidget {
  const MenuManagement({super.key});

  @override
  State<MenuManagement> createState() => _MenuManagementState();
}

class _MenuManagementState extends State<MenuManagement> {
  final Map<String, String> menu = {
    'Monday': 'Dal, Rice, Roti, Sabzi',
    'Tuesday': 'Dal, Rice, Roti, Paneer',
    'Wednesday': 'Dal, Rice, Roti, Mix Veg',
    'Thursday': 'Dal, Rice, Roti, Chole',
    'Friday': 'Dal, Rice, Roti, Aloo Sabzi',
    'Saturday': 'Dal, Rice, Roti, Paneer',
    'Sunday': 'Special Dinner',
  };

  void _editMenu(String day) {
    final controller = TextEditingController(text: menu[day]);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit $day Menu'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Menu',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                menu[day] = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
      ),
      body: ListView(
        children: menu.entries.map((entry) {
          return ListTile(
            title: Text(entry.key),
            subtitle: Text(entry.value),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editMenu(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}