import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  bool _isLoading = true;
  bool _isEditing = false;

  final _usernameCtrl = TextEditingController();
  DateTime? _dob;
  String _gender = 'Male';

  String _email = '';
  String _role = 'member';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ---------------- LOAD PROFILE ----------------
  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    _email = data['email'] ?? '';
    _role = data['role'] ?? 'member';
    _usernameCtrl.text = data['username'] ?? '';
    _gender = data['gender'] ?? 'Male';
    _avatarUrl = data['profile_image_url'];

    _dob = data['date_of_birth'] != null
        ? DateTime.parse(data['date_of_birth'])
        : null;

    setState(() => _isLoading = false);
  }

  // ---------------- VALIDATION ----------------
  bool _isValidDOB(DateTime dob) {
    final now = DateTime.now();
    if (dob.isAfter(now)) return false;

    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 1 && age <= 100;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- SAVE PROFILE ----------------
  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_usernameCtrl.text.trim().isEmpty) {
      _showError('Username is required');
      return;
    }

    if (_dob == null || !_isValidDOB(_dob!)) {
      _showError('Please select a valid date of birth');
      return;
    }

    await supabase.from('profiles').update({
      'username': _usernameCtrl.text.trim(),
      'gender': _gender,
      'date_of_birth': _dob!.toIso8601String(),
      'profile_image_url': _avatarUrl,
    }).eq('id', user.id);

    setState(() => _isEditing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
  }

  // ---------------- IMAGE UPLOAD ----------------
  Future<void> _pickAvatar() async {
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    try {
      final user = supabase.auth.currentUser!;
      final fileBytes = await File(file.path).readAsBytes();
      final filePath = '${user.id}.png';

      await supabase.storage.from('avatars').uploadBinary(
        filePath,
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );

      // Public URL is deterministic for this file path
      final url =
          supabase.storage.from('avatars').getPublicUrl(filePath);

      // Persist URL in profile so it survives navigation / reload
      await supabase
          .from('profiles')
          .update({'profile_image_url': url}).eq('id', user.id);

      if (mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload avatar')),
      );
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------- AVATAR ----------
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: ClipOval(
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: _avatarUrl == null
                          ? Container(
                              color: Colors.indigo.shade100,
                              child: Center(
                                child: Text(
                                  _usernameCtrl.text.isNotEmpty
                                      ? _usernameCtrl.text[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                            )
                          : Image.network(
                              _avatarUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ---------- USERNAME ----------
              Center(
                child: _isEditing
                    ? SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _usernameCtrl,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: 'Username',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      )
                    : Text(
                        _usernameCtrl.text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 6),
              Center(
                child: Chip(
                  label: Text(_role.toUpperCase()),
                  backgroundColor: Colors.indigo.shade50,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ---------- SINGLE CARD ----------
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const ProfileRow(
                        icon: Icons.lock_outline,
                        label: 'Account Security',
                        value: 'Email Verified',
                      ),
                      const Divider(),

                      const ProfileRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy',
                        value: 'Protected',
                      ),
                      const Divider(),

                      ProfileRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: _email,
                      ),
                      const Divider(),

                      ProfileRow(
                        icon: Icons.cake_outlined,
                        label: 'Date of Birth',
                        valueWidget: _isEditing
                            ? TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _dob ?? DateTime(2000),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() => _dob = picked);
                                  }
                                },
                                child: Text(
                                  _dob == null
                                      ? 'Select date'
                                      : _formatDate(_dob!),
                                ),
                              )
                            : Text(
                                _dob == null
                                    ? '-'
                                    : _formatDate(_dob!),
                              ),
                      ),
                      const Divider(),

                      ProfileRow(
                        icon: Icons.wc_outlined,
                        label: 'Gender',
                        valueWidget: _isEditing
                            ? DropdownButton<String>(
                                value: _gender,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'Male',
                                      child: Text('Male')),
                                  DropdownMenuItem(
                                      value: 'Female',
                                      child: Text('Female')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _gender = v!),
                              )
                            : Text(_gender),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text('Save Profile'),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

// ---------------- REUSABLE ROW ----------------
class ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;

  const ProfileRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          valueWidget ??
              Text(
                value ?? '',
                style: TextStyle(color: Colors.grey.shade600),
              ),
        ],
      ),
    );
  }
}
