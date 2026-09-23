import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class StudentProfile extends StatefulWidget {
  const StudentProfile({super.key});

  @override
  State<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends State<StudentProfile> {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, dynamic>? _studentData;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
  }

  // ------------------------------------------------------------
  // LOAD PROFILE
  // ------------------------------------------------------------

  Future<void> _loadStudentProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          _errorMessage = 'Student is not logged in.';
          _isLoading = false;
        });
        return;
      }

      final data = await _firestoreService.get(
        'students',
        user.uid,
      );

      if (!mounted) return;

      setState(() {
        _studentData = data;
        _isLoading = false;

        if (data == null) {
          _errorMessage = 'Student profile not found.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load student profile.';
        _isLoading = false;
      });
    }
  }

  // ------------------------------------------------------------
  // EDIT PROFILE
  // ------------------------------------------------------------

  Future<void> _editProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || _studentData == null) {
      return;
    }

    final nameController = TextEditingController(
      text: _studentData!['name']?.toString() ?? '',
    );

    final contactController = TextEditingController(
      text: _studentData!['contactNumber']?.toString() ?? '',
    );

    final collegeController = TextEditingController(
      text: _studentData!['college']?.toString() ?? '',
    );

    final hostelController = TextEditingController(
      text: _studentData!['hostel']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  TextFormField(
                    controller: contactController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter contact number';
                      }

                      if (!RegExp(
                        r'^[0-9]{10}$',
                      ).hasMatch(value.trim())) {
                        return 'Enter a valid 10-digit number';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  TextFormField(
                    controller: collegeController,
                    decoration: const InputDecoration(
                      labelText: 'College',
                      prefixIcon: Icon(Icons.school),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter college name';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  TextFormField(
                    controller: hostelController,
                    decoration: const InputDecoration(
                      labelText: 'Hostel',
                      prefixIcon: Icon(Icons.home),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter hostel name';
                      }

                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.pop(dialogContext);

                await _updateStudentProfile(
                  nameController.text.trim(),
                  contactController.text.trim(),
                  collegeController.text.trim(),
                  hostelController.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    contactController.dispose();
    collegeController.dispose();
    hostelController.dispose();
  }

  Future<void> _updateStudentProfile(
      String name,
      String contactNumber,
      String college,
      String hostel,
      ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestoreService.update(
        'students',
        user.uid,
        {
          'name': name,
          'contactNumber': contactNumber,
          'college': college,
          'hostel': hostel,
        },
      );

      await _loadStudentProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update profile.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // CHANGE PASSWORD
  // ------------------------------------------------------------

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter current password';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter new password';
                      }

                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your new password';
                      }

                      if (value != newPasswordController.text) {
                        return 'Passwords do not match';
                      }

                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.pop(dialogContext);

                await _updatePassword(
                  currentPasswordController.text,
                  newPasswordController.text,
                );
              },
              child: const Text('Change Password'),
            ),
          ],
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _updatePassword(
      String currentPassword,
      String newPassword,
      ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(newPassword);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Failed to change password.';

      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Current password is incorrect.';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please log in again and try changing the password.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong.'),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to logout.'),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStudentProfile,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Student Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          _profileItem(
            Icons.person,
            'Name',
            _studentData?['name'] ?? 'Not available',
          ),

          _profileItem(
            Icons.email,
            'Email',
            _studentData?['email'] ?? 'Not available',
          ),

          _profileItem(
            Icons.phone,
            'Contact',
            _studentData?['contactNumber'] ?? 'Not available',
          ),

          _profileItem(
            Icons.school,
            'College',
            _studentData?['college'] ?? 'Not available',
          ),

          _profileItem(
            Icons.home,
            'Hostel',
            _studentData?['hostel'] ?? 'Not available',
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _editProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock),
              label: const Text('Change Password'),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileItem(
      IconData icon,
      String title,
      String value,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}