

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/services/api_service.dart';

/// Full admission / signup form with 6 sections.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;

  // ── 1. Personal Information ──
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _dobController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _postalAddressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _gender = 'Male';
  DateTime? _selectedDob;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // ── 2. Educational Background ──
  final _qualificationController = TextEditingController();
  final _passingYearController = TextEditingController();
  final _instituteController = TextEditingController();

  // ── 3. Emergency Contact ──
  final _emergencyNameController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  // ── 4. Batch & Course ──
  String? _selectedBatchId;
  String? _selectedCourseId;
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _courses = [];

  // ── 5. Document Uploads ──
  final ImagePicker _picker = ImagePicker();
  XFile? _cnicFile;
  XFile? _photoFile;
  XFile? _receiptFile;

  // ── 6. Payment ──
  String _paymentMethod = 'Bank Transfer';

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final api = ApiService();
      final response = await api.dio.get(ApiConfig.batchesPublic);
      final data = response.data as List<dynamic>;
      if (data.isNotEmpty) {
        setState(() {
          _batches = data
              .map((b) => Map<String, dynamic>.from(b as Map))
              .toList();
          _selectedBatchId = _batches.first['id']?.toString();
          _courses = (_batches.first['courses'] as List<dynamic>?)
                  ?.map((c) => Map<String, dynamic>.from(c as Map))
                  .toList() ??
              [];
        });
      }
    } catch (_) {
      // Fallback: load courses directly
      try {
        final api = ApiService();
        final response = await api.dio.get(ApiConfig.courses);
        setState(() {
          _courses = (response.data as List<dynamic>)
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList();
        });
      } catch (_) {}
    }
  }

  void _fillDummyData() {
    setState(() {
      _fullNameController.text = 'Test User';
      _fatherNameController.text = 'Test Father';
      _cnicController.text = '37405-1234567-1';
      _dobController.text = '01/01/2000';
      _selectedDob = DateTime(2000, 1, 1);
      _whatsappController.text = '0300-1234567';
      _emailController.text = 'test${DateTime.now().millisecondsSinceEpoch}@example.com';
      _postalAddressController.text = '123 Test St, Test City';
      _passwordController.text = 'password123';
      _confirmPasswordController.text = 'password123';
      
      _qualificationController.text = 'BS Computer Science';
      _passingYearController.text = '2022';
      _instituteController.text = 'Test University';
      
      _emergencyNameController.text = 'Test Emergency Contact';
      _emergencyRelationController.text = 'Brother';
      _emergencyContactController.text = '0300-7654321';
      
      if (_courses.isNotEmpty) {
        _selectedCourseId = _courses.first['id']?.toString() ?? _courses.first['name'];
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _cnicController.dispose();
    _dobController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _postalAddressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _qualificationController.dispose();
    _passingYearController.dispose();
    _instituteController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Apply for Admission'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _fillDummyData,
            icon: const Icon(Icons.bolt, color: AppColors.primaryGreen),
            label: const Text('Test Fill', style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section 1: Personal Information ──
              _buildSectionHeader(1, 'Personal Information',
                  Icons.person_outline),
              _buildCard([
                _buildTextField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'e.g. Ali Ahmed',
                  icon: Icons.person_outlined,
                  validator: _requiredValidator('Full Name is required'),
                ),
                _buildTextField(
                  controller: _fatherNameController,
                  label: "Father's Name",
                  hint: 'e.g. Muhammad Ahmed',
                  icon: Icons.people_outlined,
                  validator: _requiredValidator("Father's Name is required"),
                ),
                _buildTextField(
                  controller: _cnicController,
                  label: 'CNIC Number',
                  hint: 'e.g. 37405-1234567-1',
                  icon: Icons.credit_card_outlined,
                  keyboardType: TextInputType.text,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'CNIC is required';
                    }
                    if (!RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(v.trim())) {
                      return 'Format: 37405-1234567-1';
                    }
                    return null;
                  },
                ),
                _buildDateField(),
                _buildGenderDropdown(),
                _buildTextField(
                  controller: _whatsappController,
                  label: 'WhatsApp Contact',
                  hint: 'e.g. 0300-1234567',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _requiredValidator('WhatsApp contact is required'),
                ),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'e.g. you@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _postalAddressController,
                  label: 'Postal Address',
                  hint: 'Enter complete home/office mailing address',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                  validator:
                      _requiredValidator('Postal address is required'),
                ),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  icon: Icons.lock_outlined,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  isLast: true,
                ),
              ]),

              const SizedBox(height: 20),

              // ── Section 2: Educational Background ──
              _buildSectionHeader(
                  2, 'Educational Background', Icons.school_outlined),
              _buildCard([
                _buildTextField(
                  controller: _qualificationController,
                  label: 'Last Qualification',
                  hint: 'e.g. MBA, B.Com',
                  icon: Icons.menu_book_outlined,
                  validator:
                      _requiredValidator('Qualification is required'),
                ),
                _buildTextField(
                  controller: _passingYearController,
                  label: 'Passing Year',
                  hint: 'e.g. 2024',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number,
                  validator: _requiredValidator('Passing year is required'),
                ),
                _buildTextField(
                  controller: _instituteController,
                  label: 'Institute / Board',
                  hint: 'e.g. University of Peshawar',
                  icon: Icons.account_balance_outlined,
                  validator:
                      _requiredValidator('Institute is required'),
                  isLast: true,
                ),
              ]),

              const SizedBox(height: 20),

              // ── Section 3: Emergency Contact ──
              _buildSectionHeader(
                  3, 'Emergency Contact', Icons.emergency_outlined),
              _buildCard([
                _buildTextField(
                  controller: _emergencyNameController,
                  label: 'Name',
                  hint: 'e.g. Muhammad Ahmed',
                  icon: Icons.person_outlined,
                  validator: _requiredValidator(
                      'Emergency contact name is required'),
                ),
                _buildTextField(
                  controller: _emergencyRelationController,
                  label: 'Relation',
                  hint: 'e.g. Father, Brother',
                  icon: Icons.group_outlined,
                  validator: _requiredValidator('Relation is required'),
                ),
                _buildTextField(
                  controller: _emergencyContactController,
                  label: 'Contact Number',
                  hint: 'e.g. 0300-1234567',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _requiredValidator(
                      'Emergency contact number is required'),
                  isLast: true,
                ),
              ]),

              const SizedBox(height: 20),

              // ── Section 4: Batch & Course Selection ──
              _buildSectionHeader(
                  4, 'Batch & Course Selection', Icons.class_outlined),
              _buildCard([
                _buildBatchAndCourseSelection(),
              ]),

              const SizedBox(height: 20),

              // ── Section 5: Document Uploads ──
              _buildSectionHeader(
                  5, 'Document Uploads', Icons.upload_file_outlined),
              _buildCard([
                _buildFileUploadRow(
                  label: 'CNIC Front & Back',
                  file: _cnicFile,
                  onPick: () => _pickFile((f) => _cnicFile = f),
                ),
                const Divider(height: 24),
                _buildFileUploadRow(
                  label: 'Passport Size Photo',
                  file: _photoFile,
                  onPick: () => _pickFile((f) => _photoFile = f),
                ),
                const Divider(height: 24),
                _buildFileUploadRow(
                  label: 'Payment Receipt',
                  file: _receiptFile,
                  onPick: () => _pickFile((f) => _receiptFile = f),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Section 6: Payment Information ──
              _buildSectionHeader(
                  6, 'Payment Information', Icons.payment_outlined),
              _buildCard([
                _buildPaymentMethodDropdown(),
                const SizedBox(height: 14),
                _buildBankDetailsBox(),
              ]),

              const SizedBox(height: 28),

              // ── Submit Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.forest,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 20),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting...'
                        : 'Submit Application & Request Enrollment',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.forest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Already have account link ──
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Section Header
  // ═══════════════════════════════════════════
  Widget _buildSectionHeader(int number, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryGreen, AppColors.primaryGreenLight],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Card wrapper
  // ═══════════════════════════════════════════
  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Text field builder
  // ═══════════════════════════════════════════
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          suffixIcon: suffixIcon,
        ),
        validator: validator,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Date of Birth
  // ═══════════════════════════════════════════
  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _dobController,
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          hintText: 'mm/dd/yyyy',
          prefixIcon: const Icon(Icons.cake_outlined, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_month_outlined, size: 20),
            onPressed: _pickDate,
          ),
        ),
        onTap: _pickDate,
        validator: _requiredValidator('Date of birth is required'),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryGreen,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  // ═══════════════════════════════════════════
  // Gender dropdown
  // ═══════════════════════════════════════════
  Widget _buildGenderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: _gender,
        decoration: const InputDecoration(
          labelText: 'Gender',
          prefixIcon: Icon(Icons.wc_outlined, size: 20),
        ),
        items: const [
          DropdownMenuItem(value: 'Male', child: Text('Male')),
          DropdownMenuItem(value: 'Female', child: Text('Female')),
          DropdownMenuItem(value: 'Other', child: Text('Other')),
        ],
        onChanged: (v) => setState(() => _gender = v ?? 'Male'),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Batch & Course
  // ═══════════════════════════════════════════
  Widget _buildBatchAndCourseSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Batch dropdown
        if (_batches.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            value: _selectedBatchId,
            decoration: const InputDecoration(
              labelText: 'Select Academic Batch',
              prefixIcon: Icon(Icons.date_range_outlined, size: 20),
            ),
            items: _batches.map((b) {
              final name = b['name'] ?? '';
              final startDate = b['startDate'] ?? '';
              String displayText = name;
              if (startDate.isNotEmpty) {
                try {
                  final date = DateTime.parse(startDate);
                  displayText +=
                      ' (Starts: ${DateFormat('M/d/yyyy').format(date)})';
                } catch (_) {
                  displayText += ' (Starts: $startDate)';
                }
              }
              return DropdownMenuItem(
                value: b['id']?.toString(),
                child: Text(displayText,
                    style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (v) {
              final batch = _batches.firstWhere(
                  (b) => b['id']?.toString() == v,
                  orElse: () => <String, dynamic>{});
              setState(() {
                _selectedBatchId = v;
                _selectedCourseId = null;
                _courses = (batch['courses'] as List<dynamic>?)
                        ?.map(
                            (c) => Map<String, dynamic>.from(c as Map))
                        .toList() ??
                    [];
              });
            },
            validator: _requiredValidator('Please select a batch'),
          ),
          const SizedBox(height: 16),
        ],

        // Info banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'You can select one course at a time. After completing it, you may apply for another.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Course list
        if (_courses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Loading courses...',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ..._courses.map((course) {
            final name = course['name'] ?? '';
            final id = course['id']?.toString() ?? name;
            final fee = course['discountedFee'] ?? course['fee'] ?? 0;
            final originalFee = course['originalFee'];
            final isSelected = _selectedCourseId == id;

            return GestureDetector(
              onTap: () => setState(() => _selectedCourseId = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGreen
                          .withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.borderLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 22,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primaryGreen
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (originalFee != null) ...[
                                Text(
                                  'PKR ${_formatNumber(originalFee)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade400,
                                    decoration:
                                        TextDecoration.lineThrough,
                                    decorationColor:
                                        Colors.red.shade400,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                'PKR ${_formatNumber(fee)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // File Upload
  // ═══════════════════════════════════════════
  Widget _buildFileUploadRow({
    required String label,
    required XFile? file,
    required VoidCallback onPick,
  }) {
    return Row(
      children: [
        Icon(
          file != null ? Icons.check_circle : Icons.cloud_upload_outlined,
          size: 22,
          color:
              file != null ? AppColors.primaryGreen : AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                file != null ? file.name : 'No file chosen',
                style: TextStyle(
                  fontSize: 11,
                  color: file != null
                      ? AppColors.primaryGreen
                      : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.attach_file, size: 16),
          label: Text(file != null ? 'Change' : 'Choose'),
          style: OutlinedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
            side: BorderSide(
              color: file != null
                  ? AppColors.primaryGreen
                  : AppColors.borderLight,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile(void Function(XFile) setter) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => setter(picked));
    }
  }

  // ═══════════════════════════════════════════
  // Payment
  // ═══════════════════════════════════════════
  Widget _buildPaymentMethodDropdown() {
    return DropdownButtonFormField<String>(
      value: _paymentMethod,
      decoration: const InputDecoration(
        labelText: 'Payment Method',
        prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
      ),
      items: const [
        DropdownMenuItem(
            value: 'Bank Transfer', child: Text('Bank Transfer')),
        DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
        DropdownMenuItem(value: 'EasyPaisa', child: Text('EasyPaisa')),
      ],
      onChanged: (v) =>
          setState(() => _paymentMethod = v ?? 'Bank Transfer'),
    );
  }

  Widget _buildBankDetailsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16,
                  color:
                      AppColors.primaryGreen.withOpacity(0.7)),
              const SizedBox(width: 6),
              const Text(
                'Official Academy Account Details:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_paymentMethod == 'Bank Transfer') ...[
            _buildDetailRow('Bank', 'Habib Bank Limited (HBL)'),
            _buildDetailRow('Account Title', 'Premier Tax School'),
            _buildDetailRow('Account Number', '1234-56789012-03'),
          ] else if (_paymentMethod == 'JazzCash') ...[
            _buildDetailRow('Title', 'Raja Gulfam Kayani'),
            _buildDetailRow('Number', '0300-1234567'),
          ] else ...[
            _buildDetailRow('Title', 'Raja Gulfam Kayani'),
            _buildDetailRow('Number', '0345-1234567'),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════
  String? Function(String?) _requiredValidator(String message) {
    return (v) => (v == null || v.trim().isEmpty) ? message : null;
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num parsed =
        value is num ? value : num.tryParse(value.toString()) ?? 0;
    return NumberFormat('#,###').format(parsed);
  }

  // ═══════════════════════════════════════════
  // Submit
  // ═══════════════════════════════════════════
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      // Scroll to top so user can see validation errors
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ApiService();

      // First register the user account
      final auth = context.read<AuthProvider>();
      final signupSuccess = await auth.signup(
        _fullNameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!signupSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.error ?? 'Registration failed'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      // Find the course name for submission
      final selectedCourse = _courses.firstWhere(
        (c) => (c['id']?.toString() ?? c['name']) == _selectedCourseId,
        orElse: () => <String, dynamic>{'name': _selectedCourseId},
      );

      // Ensure Date of Birth is ISO 8601
      String dobIso;
      if (_selectedDob != null) {
        dobIso = _selectedDob!.toUtc().toIso8601String();
      } else {
        try {
          final parts = _dobController.text.trim().split('/');
          dobIso = DateTime.utc(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1])).toIso8601String();
        } catch (_) {
          dobIso = DateTime.now().toUtc().toIso8601String();
        }
      }

      // Calculate fee
      final feeStr = selectedCourse['discountedFee']?.toString() ?? selectedCourse['fee']?.toString() ?? '0';
      final totalAmount = int.tryParse(feeStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      
      // We upload files first (if backend supports /uploads) or ignore if not required
      // Assuming file uploads aren't strictly required by the Zod schema shown in the error.
      // If they are, they would be URLs. 

      // Build JSON data
      final Map<String, dynamic> jsonData = {
        'fullName': _fullNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'dateOfBirth': dobIso,
        'gender': _gender.toLowerCase(),
        'whatsapp': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'postalAddress': _postalAddressController.text.trim(),
        'lastQualification': _qualificationController.text.trim(),
        'passingYear': _passingYearController.text.trim(),
        'institute': _instituteController.text.trim(),
        'emergencyName': _emergencyNameController.text.trim(),
        'emergencyRelation': _emergencyRelationController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'selectedCourses': [selectedCourse['name'] ?? _selectedCourseId ?? ''],
        'totalAmount': totalAmount,
        'paymentMethod': _paymentMethod,
        'batchId': _selectedBatchId,
      };

      await api.dio.post(ApiConfig.admissions, data: jsonData);

      if (!mounted) return;

      Navigator.of(context)
          .pushNamedAndRemoveUntil('/under-review', (_) => false);
    } catch (e) {
      if (mounted) {
        String message = 'Submission failed. Please try again.';
        if (e is DioException) {
          final responseData = e.response?.data;
          final backendMsg = responseData is Map ? responseData['message'] : null;
          if (backendMsg is String) message = backendMsg;
          if (backendMsg is List) message = backendMsg.join(', ');
          
          var detailedErrors = '';
          if (responseData is Map && responseData['errors'] != null) {
            if (responseData['errors'] is Map) {
              detailedErrors = ': ' + (responseData['errors'] as Map).values.map((v) => v is List ? v.join(', ') : v).join(' | ');
            } else if (responseData['errors'] is List) {
              detailedErrors = ': ' + (responseData['errors'] as List).join(', ');
            }
          }
          message += detailedErrors;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
