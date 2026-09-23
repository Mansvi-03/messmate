import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class MenuChangeScreen extends StatefulWidget {
  const MenuChangeScreen({
    super.key,
    required this.day,
    required this.meal,
    required this.currentMenu,
  });

  final String day;
  final String meal;
  final String currentMenu;

  @override
  State<MenuChangeScreen> createState() =>
      _MenuChangeScreenState();
}

class _MenuChangeScreenState
    extends State<MenuChangeScreen> {
  final FirestoreService _firestoreService =
  FirestoreService();

  final _formKey = GlobalKey<FormState>();

  final _proposedMenuController =
  TextEditingController();

  final _reasonController =
  TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _proposedMenuController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // SUBMIT MENU CHANGE REQUEST
  // ----------------------------------------------------------

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please login first.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final studentData =
      await _firestoreService.get(
        'students',
        user.uid,
      );

      if (studentData == null) {
        throw Exception(
          'Student profile not found.',
        );
      }

      final requestId =
      DateTime.now()
          .millisecondsSinceEpoch
          .toString();

      await _firestoreService.add(
        'menu_change_requests',
        requestId,
        {
          'studentId': user.uid,

          'studentName':
          studentData['name'] ?? '',

          'day': widget.day,

          'meal': widget.meal,

          'currentMenu':
          widget.currentMenu,

          'proposedMenu':
          _proposedMenuController.text
              .trim(),

          'reason':
          _reasonController.text
              .trim(),

          'createdAt':
          DateTime.now()
              .toIso8601String(),

          'status': 'pending',
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Menu change suggestion submitted.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to submit suggestion.',
          ),
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

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Suggest Menu Change',
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              // DAY
              Text(
                widget.day,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // MEAL
              Text(
                widget.meal,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(height: 25),

              // CURRENT MENU
              const Text(
                'Current Menu',
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(15),

                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                  ),
                  borderRadius:
                  BorderRadius.circular(8),
                ),

                child: Text(
                  widget.currentMenu,
                ),
              ),

              const SizedBox(height: 25),

              // PROPOSED MENU
              TextFormField(
                controller:
                _proposedMenuController,

                maxLines: 3,

                decoration:
                const InputDecoration(
                  labelText:
                  'Proposed Menu',

                  hintText:
                  'Enter your suggested menu',

                  border:
                  OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter proposed menu';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              // REASON
              TextFormField(
                controller:
                _reasonController,

                maxLines: 3,

                decoration:
                const InputDecoration(
                  labelText: 'Reason',

                  hintText:
                  'Why should the menu change?',

                  border:
                  OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter a reason';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 30),

              // SUBMIT
              SizedBox(
                width: double.infinity,

                child: ElevatedButton(
                  onPressed:
                  _isSaving
                      ? null
                      : _submitRequest,

                  child: _isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,

                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Submit Suggestion',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}