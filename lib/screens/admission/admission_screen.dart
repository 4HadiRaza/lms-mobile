import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/services/api_service.dart';

/// Multi-step admission form using a Stepper widget.
class AdmissionScreen extends StatefulWidget {
  const AdmissionScreen({super.key});

  @override
  State<AdmissionScreen> createState() => _AdmissionScreenState();
}

class _AdmissionScreenState extends State<AdmissionScreen> {
  int _currentStep = 0;
  bool _submitting = false;
  String? _successMessage;

  // Form controllers
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _dobController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _postalAddressController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _passingYearController = TextEditingController();
  final _instituteController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  String _gender = 'male';
  String? _selectedBatchId;
  String? _selectedCourse;
  String _paymentMethod = 'Bank Transfer';

  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();

    // Pre-fill user data
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      _fullNameController.text = auth.user!.name;
      _emailController.text = auth.user!.email;
    }

    // Load batches
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
      // Load courses as fallback
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _cnicController.dispose();
    _dobController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _postalAddressController.dispose();
    _qualificationController.dispose();
    _passingYearController.dispose();
    _instituteController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Enrollment Application'),
      ),
      body: _successMessage != null
          ? _buildSuccess()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Stepper(
                  type: StepperType.vertical,
                  currentStep: _currentStep,
                  onStepContinue: _onContinue,
                  onStepCancel: _onCancel,
                  controlsBuilder: _controlsBuilder,
                  steps: [
                    _buildPersonalInfoStep(),
                    _buildEducationStep(),
                    _buildEmergencyStep(),
                    _buildCourseSelectionStep(),
                    _buildPaymentStep(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 32, color: Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            const Text(
              'Application Received!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _successMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Step _buildPersonalInfoStep() {
    return Step(
      title: const Text('Personal Info'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          TextField(
            controller: _fullNameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
            readOnly: context.read<AuthProvider>().isLoggedIn,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fatherNameController,
            decoration: const InputDecoration(labelText: "Father's Name"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cnicController,
            decoration: const InputDecoration(
                labelText: 'CNIC Number', hintText: '37405-1234567-1'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dobController,
            decoration: const InputDecoration(
                labelText: 'Date of Birth', hintText: 'YYYY-MM-DD'),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'male'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsappController,
            decoration: const InputDecoration(
                labelText: 'WhatsApp Contact',
                hintText: '0300-1234567'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email Address'),
            readOnly: context.read<AuthProvider>().isLoggedIn,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postalAddressController,
            decoration: const InputDecoration(labelText: 'Postal Address'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Step _buildEducationStep() {
    return Step(
      title: const Text('Education'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          TextField(
            controller: _qualificationController,
            decoration: const InputDecoration(
                labelText: 'Last Qualification', hintText: 'e.g. MBA'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passingYearController,
            decoration: const InputDecoration(
                labelText: 'Passing Year', hintText: 'e.g. 2024'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instituteController,
            decoration: const InputDecoration(
                labelText: 'Institute / Board'),
          ),
        ],
      ),
    );
  }

  Step _buildEmergencyStep() {
    return Step(
      title: const Text('Emergency Contact'),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          TextField(
            controller: _emergencyNameController,
            decoration: const InputDecoration(labelText: 'Contact Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emergencyRelationController,
            decoration: const InputDecoration(
                labelText: 'Relation', hintText: 'e.g. Father'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emergencyContactController,
            decoration: const InputDecoration(labelText: 'Phone Number'),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Step _buildCourseSelectionStep() {
    return Step(
      title: const Text('Course Selection'),
      isActive: _currentStep >= 3,
      state: _currentStep > 3 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_batches.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedBatchId,
              decoration: const InputDecoration(labelText: 'Select Batch'),
              items: _batches.map((b) {
                return DropdownMenuItem(
                  value: b['id']?.toString(),
                  child: Text(b['name'] ?? ''),
                );
              }).toList(),
              onChanged: (v) {
                final batch = _batches.firstWhere(
                    (b) => b['id']?.toString() == v,
                    orElse: () => {});
                setState(() {
                  _selectedBatchId = v;
                  _selectedCourse = null;
                  _courses = (batch['courses'] as List<dynamic>?)
                          ?.map((c) =>
                              Map<String, dynamic>.from(c as Map))
                          .toList() ??
                      [];
                });
              },
            ),
            const SizedBox(height: 16),
          ],
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
                    'You can select one course at a time.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._courses.map((course) {
            final name = course['name'] ?? '';
            final fee = course['discountedFee'] ?? 0;
            final originalFee = course['originalFee'];
            final isSelected = _selectedCourse == name;
            return GestureDetector(
              onTap: () => setState(() => _selectedCourse = name),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGreen.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
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
                      size: 20,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (originalFee != null)
                                Text(
                                  'PKR ${originalFee.toString()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    decoration:
                                        TextDecoration.lineThrough,
                                  ),
                                ),
                              if (originalFee != null)
                                const SizedBox(width: 6),
                              Text(
                                'PKR $fee',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Step _buildPaymentStep() {
    return Step(
      title: const Text('Payment'),
      isActive: _currentStep >= 4,
      state: _currentStep > 4 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(
                  value: 'Bank Transfer', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
              DropdownMenuItem(
                  value: 'EasyPaisa', child: Text('EasyPaisa')),
            ],
            onChanged: (v) =>
                setState(() => _paymentMethod = v ?? 'Bank Transfer'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Details:',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (_paymentMethod == 'Bank Transfer') ...[
                  const Text('Bank: Habib Bank Limited (HBL)',
                      style: TextStyle(fontSize: 12)),
                  const Text('Title: Premier Tax School',
                      style: TextStyle(fontSize: 12)),
                  const Text('Account: 1234-56789012-03',
                      style: TextStyle(fontSize: 12)),
                ] else if (_paymentMethod == 'JazzCash') ...[
                  const Text('Title: Raja Gulfam Kayani',
                      style: TextStyle(fontSize: 12)),
                  const Text('Number: 0300-1234567',
                      style: TextStyle(fontSize: 12)),
                ] else ...[
                  const Text('Title: Raja Gulfam Kayani',
                      style: TextStyle(fontSize: 12)),
                  const Text('Number: 0345-1234567',
                      style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Note: Please upload your CNIC, photo, and payment receipt via the web portal for now. Mobile document upload coming soon.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlsBuilder(
      BuildContext context, ControlsDetails details) {
    final isLast = _currentStep == 4;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: _submitting ? null : details.onStepContinue,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isLast ? 'Submit Application' : 'Continue'),
          ),
          if (_currentStep > 0) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: details.onStepCancel,
              child: const Text('Back'),
            ),
          ],
        ],
      ),
    );
  }

  void _onContinue() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    } else {
      _submitApplication();
    }
  }

  void _onCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitApplication() async {
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final api = ApiService();
      await api.dio.post(ApiConfig.admissions, data: {
        'fullName': _fullNameController.text,
        'fatherName': _fatherNameController.text,
        'cnic': _cnicController.text,
        'dateOfBirth': _dobController.text,
        'gender': _gender,
        'whatsapp': _whatsappController.text,
        'email': _emailController.text,
        'postalAddress': _postalAddressController.text,
        'lastQualification': _qualificationController.text,
        'passingYear': _passingYearController.text,
        'institute': _instituteController.text,
        'emergencyName': _emergencyNameController.text,
        'emergencyRelation': _emergencyRelationController.text,
        'emergencyContact': _emergencyContactController.text,
        'selectedCourses': [_selectedCourse],
        'paymentMethod': _paymentMethod,
        'batchId': _selectedBatchId,
      });

      setState(() {
        _successMessage =
            'Your application has been submitted successfully! An administrator will review and approve your enrollment shortly.';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit. Please try again.')),
        );
      }
    } finally {
      setState(() => _submitting = false);
    }
  }
}
