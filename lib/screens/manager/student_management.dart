import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class StudentManagement extends StatefulWidget {
  const StudentManagement({super.key});

  @override
  State<StudentManagement> createState() => _StudentManagementState();
}

class _StudentManagementState extends State<StudentManagement> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = true;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await _firestoreService.getAll('students');

      if (!mounted) return;

      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load students: $e'),
        ),
      );
    }
  }

  // ==========================================
  // CREATE: ADD STUDENT
  // ==========================================
  Future<void> _addStudent() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final contactController = TextEditingController();
    final collegeController = TextEditingController();
    final hostelController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Student'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: collegeController,
                        decoration: const InputDecoration(
                          labelText: 'College',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: hostelController,
                        decoration: const InputDecoration(
                          labelText: 'Hostel',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);

                          try {
                            final id = DateTime.now().millisecondsSinceEpoch.toString();
                            await _firestoreService.add('students', id, {
                              'name': nameController.text.trim(),
                              'email': emailController.text.trim(),
                              'contactNumber': contactController.text.trim(),
                              'college': collegeController.text.trim(),
                              'hostel': hostelController.text.trim(),
                              'role': 'student',
                            });

                            final messenger = ScaffoldMessenger.of(context);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            await _loadStudents();

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Student added successfully'),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to add student: $e'),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    contactController.dispose();
    collegeController.dispose();
    hostelController.dispose();
  }

  // ==========================================
  // UPDATE: EDIT STUDENT
  // ==========================================
  Future<void> _editStudent(Map<String, dynamic> student) async {
    final studentId = student['id']?.toString() ?? '';
    if (studentId.isEmpty) return;

    final nameController = TextEditingController(text: student['name'] ?? '');
    final emailController = TextEditingController(text: student['email'] ?? '');
    final contactController = TextEditingController(text: student['contactNumber'] ?? '');
    final collegeController = TextEditingController(text: student['college'] ?? '');
    final hostelController = TextEditingController(text: student['hostel'] ?? '');

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Student'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: collegeController,
                        decoration: const InputDecoration(
                          labelText: 'College',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: hostelController,
                        decoration: const InputDecoration(
                          labelText: 'Hostel',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);

                          try {
                            await _firestoreService.update('students', studentId, {
                              'name': nameController.text.trim(),
                              'email': emailController.text.trim(),
                              'contactNumber': contactController.text.trim(),
                              'college': collegeController.text.trim(),
                              'hostel': hostelController.text.trim(),
                            });

                            final messenger = ScaffoldMessenger.of(context);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            await _loadStudents();

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Student updated successfully'),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update student: $e'),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    contactController.dispose();
    collegeController.dispose();
    hostelController.dispose();
  }

  // ==========================================
  // DELETE: DELETE STUDENT
  // ==========================================
  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final studentId = student['id']?.toString() ?? '';
    final studentName = student['name'] ?? 'Student';
    if (studentId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete "$studentName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final messenger = ScaffoldMessenger.of(context);
      await _firestoreService.delete('students', studentId);

      await _loadStudents();

      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted student "$studentName"'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete student: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
        actions: [
          IconButton(
            onPressed: _addStudent,
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Student',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStudent,
        tooltip: 'Add Student',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _students.isEmpty
              ? const Center(
                  child: Text('No students registered'),
                )
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: ListView.builder(
                    itemCount: _students.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final name = student['name'] ?? 'Unknown Student';
                      final email = student['email'] ?? '';
                      final contact = student['contactNumber'] ?? '';
                      final college = student['college'] ?? '';
                      final hostel = student['hostel'] ?? '';

                      final List<String> details = [];
                      if (contact.toString().isNotEmpty) details.add('Phone: $contact');
                      if (college.toString().isNotEmpty) details.add('College: $college');
                      if (hostel.toString().isNotEmpty) details.add('Hostel: $hostel');

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '$email${details.isNotEmpty ? '\n${details.join(' • ')}' : ''}',
                          ),
                          isThreeLine: details.isNotEmpty,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit Student',
                                onPressed: () => _editStudent(student),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete Student',
                                onPressed: () => _deleteStudent(student),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}