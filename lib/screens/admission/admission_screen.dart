import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/services/api_service.dart';

class AdmissionScreen extends StatefulWidget {
  const AdmissionScreen({super.key});

  @override
  State<AdmissionScreen> createState() => _AdmissionScreenState();
}

class _AdmissionScreenState extends State<AdmissionScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Personal Information Controllers
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _dobController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  String _gender = 'Male';

  // 2. Academic Background & Address Controllers
  final _qualificationController = TextEditingController();
  final _passingYearController = TextEditingController();
  final _instituteController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalAddressController = TextEditingController();
  String _province = 'Punjab';

  // 3. Emergency Contact Controllers
  final _emergencyNameController = TextEditingController();
  final _emergencyRelationController = TextEditingController(text: 'Guardian');
  final _emergencyContactController = TextEditingController();

  // 4. Course Selection & 5. Class Mode
  String _selectedCourse = 'Mastering Income Tax Ordinances 2001';
  int _selectedCourseFee = 15500;
  String _classMode = 'Online';

  // Payment Details
  String _paymentMethod = 'Meezan Bank Transfer';
  final _transactionIdController = TextEditingController();

  // Uploaded Files
  String? _paymentReceiptPath;
  String? _paymentReceiptName;
  String? _cnicFilePath;
  String? _cnicFileName;
  String? _photoFilePath;
  String? _photoFileName;

  // Declaration
  bool _declarationAgreed = true;

  // UI & Loading States
  bool _isLoadingCourses = true;
  bool _isSubmitting = false;
  String? _successMessage;
  String? _errorMessage;

  List<Map<String, dynamic>> _availableCourses = [
    {
      'title': 'Mastering Income Tax Ordinances 2001',
      'fee': 15500,
    },
    {
      'title': 'Corporate Accounting with IFRS Standards',
      'fee': 22500,
    },
    {
      'title': 'Certified Tax Practitioner (CTP)',
      'fee': 30000,
    },
    {
      'title': 'Advanced Tax Litigation Manager (ATLM)',
      'fee': 35000,
    },
    {
      'title': 'Certified Sales Tax Expert (CSTE)',
      'fee': 18000,
    },
    {
      'title': 'Certified Corporate Expert (CCE)',
      'fee': 25000,
    },
  ];

  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _provinceOptions = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Islamabad Capital Territory',
    'Azad Jammu & Kashmir',
    'Gilgit-Baltistan',
  ];
  final List<String> _paymentMethodOptions = [
    'Meezan Bank Transfer',
    'JazzCash / EasyPaisa',
    'Online Banking / ATM Transfer',
    'Cash at Campus',
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Pre-fill user data if already logged in
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn && auth.user != null) {
      _fullNameController.text = auth.user!.name;
      _emailController.text = auth.user!.email;
    }

    _loadDynamicCourses();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _cnicController.dispose();
    _dobController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _qualificationController.dispose();
    _passingYearController.dispose();
    _instituteController.dispose();
    _cityController.dispose();
    _postalAddressController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyContactController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _loadDynamicCourses() async {
    try {
      final api = ApiService();
      final response = await api.dio.get(ApiConfig.courses);
      if (response.data is List && (response.data as List).isNotEmpty) {
        final fetched = (response.data as List).map((c) {
          final map = c as Map<String, dynamic>;
          return {
            'title': map['title'] ?? map['name'] ?? '',
            'fee': map['discountedFee'] ?? map['price'] ?? 15500,
          };
        }).toList();

        if (mounted) {
          setState(() {
            _availableCourses = fetched;
            _selectedCourse = _availableCourses.first['title'];
            _selectedCourseFee = (_availableCourses.first['fee'] as num).toInt();
            _isLoadingCourses = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingCourses = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCourses = false);
    }
  }

  // Auto-format Pakistani CNIC (xxxxx-xxxxxxx-x)
  void _onCnicChanged(String value) {
    final raw = value.replaceAll(RegExp(r'\D'), '');
    String formatted = raw;
    if (raw.length > 5 && raw.length <= 12) {
      formatted = '${raw.substring(0, 5)}-${raw.substring(5)}';
    } else if (raw.length > 12) {
      formatted = '${raw.substring(0, 5)}-${raw.substring(5, 12)}-${raw.substring(12, raw.length.clamp(12, 13))}';
    }

    if (formatted != value) {
      _cnicController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  // Auto-format Pakistani Phone (03xx-xxxxxxx)
  void _onPhoneChanged(TextEditingController controller, String value) {
    final raw = value.replaceAll(RegExp(r'\D'), '');
    String formatted = raw;
    if (raw.length > 4) {
      formatted = '${raw.substring(0, 4)}-${raw.substring(4, raw.length.clamp(4, 11))}';
    }

    if (formatted != value) {
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickFile(String type) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (file != null && mounted) {
        setState(() {
          if (type == 'receipt') {
            _paymentReceiptPath = file.path;
            _paymentReceiptName = file.name;
          } else if (type == 'cnic') {
            _cnicFilePath = file.path;
            _cnicFileName = file.name;
          } else if (type == 'photo') {
            _photoFilePath = file.path;
            _photoFileName = file.name;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
    }
  }

  Future<String?> _uploadSingleFile(String? filePath, String defaultName) async {
    if (filePath == null || filePath.isEmpty) return defaultName;
    try {
      final api = ApiService();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last.split('\\').last),
      });
      final res = await api.dio.post(ApiConfig.uploads, data: formData);
      return res.data['filename']?.toString() ?? defaultName;
    } catch (_) {
      return defaultName;
    }
  }

  Future<void> _submitForm() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = 'Please fill all required fields properly before submitting.';
      });
      return;
    }

    if (!_declarationAgreed) {
      setState(() {
        _errorMessage = 'You must agree to the declaration to proceed.';
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ApiService();

      // Format clean DOB for backend
      String formattedDob = _dobController.text.trim();
      try {
        final parsedDate = DateFormat('MM/dd/yyyy').parse(_dobController.text.trim());
        formattedDob = DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (_) {}

      // Optional file uploads
      final cnicUploaded = await _uploadSingleFile(_cnicFilePath, 'cnic_doc.png');
      final photoUploaded = await _uploadSingleFile(_photoFilePath, 'passport_photo.png');
      final receiptUploaded = await _uploadSingleFile(_paymentReceiptPath, _transactionIdController.text.trim().isNotEmpty ? _transactionIdController.text.trim() : 'receipt.png');

      final payload = {
        'fullName': _fullNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'dateOfBirth': formattedDob,
        'gender': _gender,
        'whatsapp': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'postalAddress': '${_postalAddressController.text.trim()}, ${_cityController.text.trim()}, $_province',
        'lastQualification': _qualificationController.text.trim(),
        'passingYear': _passingYearController.text.trim(),
        'institute': _instituteController.text.trim(),
        'emergencyName': _emergencyNameController.text.trim(),
        'emergencyRelation': _emergencyRelationController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'selectedCourses': [_selectedCourse],
        'totalAmount': _selectedCourseFee,
        'paymentMethod': _paymentMethod,
        'cnicFile': cnicUploaded,
        'photoFile': photoUploaded,
        'paymentProof': receiptUploaded,
      };

      await api.dio.post(ApiConfig.admissions, data: payload);

      if (mounted) {
        setState(() {
          _successMessage =
              'Your online admission application has been received! Our admissions department will review your application. Upon admin approval, your student portal login credentials will be emailed directly to ${_emailController.text.trim()}.';
        });
      }
    } catch (e) {
      String errText = 'Failed to submit admission application. Please check your information and try again.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          errText = data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString();
        }
      }
      if (mounted) {
        setState(() => _errorMessage = errText);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_successMessage != null) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Online Admission Application',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Header
                  _buildHeaderBanner(),
                  const SizedBox(height: 16),

                  if (_errorMessage != null) ...[
                    _buildErrorBanner(_errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // 1. Personal Information Section
                  _buildSectionCard(
                    stepNumber: '1',
                    title: 'Personal Information',
                    subtitle: 'Required for FBR & SECP diploma registration',
                    child: _buildPersonalInformationFields(),
                  ),
                  const SizedBox(height: 20),

                  // 2. Academic Background & Address Section
                  _buildSectionCard(
                    stepNumber: '2',
                    title: 'Academic Background & Address',
                    subtitle: 'Qualifications & dispatch postal address for certificates',
                    child: _buildAcademicAndAddressFields(),
                  ),
                  const SizedBox(height: 20),

                  // 3. Emergency Contact Information Section
                  _buildSectionCard(
                    stepNumber: '3',
                    title: 'Emergency Contact Information',
                    subtitle: 'Guardian or family emergency contact',
                    child: _buildEmergencyContactFields(),
                  ),
                  const SizedBox(height: 20),

                  // 4. Course Enrollment & 5. Class Mode Section
                  _buildCourseAndClassModeSection(),
                  const SizedBox(height: 20),

                  // Bank Account Details Box
                  _buildBankAccountDetailsCard(),
                  const SizedBox(height: 20),

                  // Payment & Uploads Section
                  _buildPaymentAndUploadsCard(),
                  const SizedBox(height: 20),

                  // Declaration Checkbox
                  _buildDeclarationCard(),
                  const SizedBox(height: 24),

                  // Submit Footer
                  _buildSubmitButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header Banner ──────────────────────────────────────────────────────────
  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 14, color: AppColors.primaryGreen),
                    const SizedBox(width: 5),
                    Text(
                      'OFFICIAL STUDENT ADMISSION PORTAL',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Online Admission Application Form',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete your registration for accredited practitioner masterclasses instructed directly by Advocate High Court & ACMA Raja Gulfam.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Container Helper ───────────────────────────────────────────────
  Widget _buildSectionCard({
    required String stepNumber,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNumber,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          child,
        ],
      ),
    );
  }

  // ── 1. Personal Information Fields ────────────────────────────────────────
  Widget _buildPersonalInformationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FULL NAME
        _buildFieldLabel('FULL NAME (AS PER CNIC) *'),
        TextFormField(
          controller: _fullNameController,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'e.g. Muhammad Ali Khan',
            prefixIcon: Icons.person_outline,
          ),
          validator: (v) => (v == null || v.trim().length < 3) ? 'Full Name is required (min 3 characters)' : null,
        ),
        const SizedBox(height: 14),

        // FATHER'S / GUARDIAN'S NAME
        _buildFieldLabel("FATHER'S / GUARDIAN'S NAME *"),
        TextFormField(
          controller: _fatherNameController,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'e.g. Tariq Mehmood Khan',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? "Father's name is required" : null,
        ),
        const SizedBox(height: 14),

        // PAKISTANI CNIC NUMBER (13 DIGITS)
        _buildFieldLabel('PAKISTANI CNIC NUMBER * (13 DIGITS)'),
        TextFormField(
          controller: _cnicController,
          keyboardType: TextInputType.number,
          maxLength: 15,
          onChanged: _onCnicChanged,
          style: GoogleFonts.robotoMono(fontSize: 13),
          decoration: _inputDecoration(
            hintText: '37405-1234567-1',
            prefixIcon: Icons.credit_card_outlined,
            helperText: 'Format: 13 digits (Auto-hyphenated)',
          ),
          validator: (v) {
            final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (clean.length != 13) return 'Please enter a valid 13-digit CNIC';
            return null;
          },
        ),
        const SizedBox(height: 14),

        // DATE OF BIRTH
        _buildFieldLabel('DATE OF BIRTH *'),
        TextFormField(
          controller: _dobController,
          readOnly: true,
          onTap: _pickDate,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'mm/dd/yyyy',
            prefixIcon: Icons.calendar_today_outlined,
            suffixIcon: Icons.arrow_drop_down,
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Date of birth is required' : null,
        ),
        const SizedBox(height: 14),

        // GENDER
        _buildFieldLabel('GENDER *'),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
          decoration: _inputDecoration(),
          items: _genderOptions
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (val) => setState(() => _gender = val ?? 'Male'),
        ),
        const SizedBox(height: 14),

        // PAKISTANI MOBILE / WHATSAPP CONTACT
        _buildFieldLabel('PAKISTANI MOBILE / WHATSAPP CONTACT *'),
        TextFormField(
          controller: _whatsappController,
          keyboardType: TextInputType.phone,
          maxLength: 12,
          onChanged: (v) => _onPhoneChanged(_whatsappController, v),
          style: GoogleFonts.robotoMono(fontSize: 13),
          decoration: _inputDecoration(
            hintText: '0300-1234567',
            prefixIcon: Icons.phone_outlined,
            helperText: '11 digits starting with 03',
          ),
          validator: (v) {
            final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (clean.length != 11 || !clean.startsWith('03')) {
              return 'Please enter a valid 11-digit number starting with 03';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        // EMAIL ADDRESS
        _buildFieldLabel('EMAIL ADDRESS *'),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'name@domain.com',
            prefixIcon: Icons.mail_outline,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email is required';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ── 2. Academic Background & Address Fields ────────────────────────────────
  Widget _buildAcademicAndAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LAST QUALIFICATION
        _buildFieldLabel('LAST QUALIFICATION *'),
        TextFormField(
          controller: _qualificationController,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'e.g. B.Com, LL.B, CA, MBA',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Qualification is required' : null,
        ),
        const SizedBox(height: 14),

        // PASSING YEAR
        _buildFieldLabel('PASSING YEAR *'),
        TextFormField(
          controller: _passingYearController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'e.g. 2023',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Passing year is required' : null,
        ),
        const SizedBox(height: 14),

        // INSTITUTE / UNIVERSITY
        _buildFieldLabel('INSTITUTE / UNIVERSITY *'),
        TextFormField(
          controller: _instituteController,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'e.g. University of the Punjab',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Institute is required' : null,
        ),
        const SizedBox(height: 14),

        // CITY NAME
        _buildFieldLabel('CITY NAME *'),
        TextFormField(
          controller: _cityController,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'e.g. Lahore, Karachi, Islamabad',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'City name is required' : null,
        ),
        const SizedBox(height: 14),

        // PROVINCE
        _buildFieldLabel('PROVINCE *'),
        DropdownButtonFormField<String>(
          initialValue: _province,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
          decoration: _inputDecoration(),
          items: _provinceOptions
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (val) => setState(() => _province = val ?? 'Punjab'),
        ),
        const SizedBox(height: 14),

        // COMPLETE POSTAL ADDRESS
        _buildFieldLabel('COMPLETE POSTAL ADDRESS *'),
        TextFormField(
          controller: _postalAddressController,
          maxLines: 2,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'House/Office No., Street, Sector/Area',
            prefixIcon: Icons.location_on_outlined,
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Postal address is required' : null,
        ),
      ],
    );
  }

  // ── 3. Emergency Contact Information Fields ────────────────────────────────
  Widget _buildEmergencyContactFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // EMERGENCY CONTACT NAME
        _buildFieldLabel('EMERGENCY CONTACT NAME *'),
        TextFormField(
          controller: _emergencyNameController,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'e.g. Tariq Mehmood',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Emergency contact name is required' : null,
        ),
        const SizedBox(height: 14),

        // RELATION
        _buildFieldLabel('RELATION *'),
        TextFormField(
          controller: _emergencyRelationController,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: _inputDecoration(
            hintText: 'Guardian',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Relation is required' : null,
        ),
        const SizedBox(height: 14),

        // EMERGENCY CONTACT NUMBER
        _buildFieldLabel('EMERGENCY CONTACT NUMBER *'),
        TextFormField(
          controller: _emergencyContactController,
          keyboardType: TextInputType.phone,
          maxLength: 12,
          onChanged: (v) => _onPhoneChanged(_emergencyContactController, v),
          style: GoogleFonts.robotoMono(fontSize: 13),
          decoration: _inputDecoration(
            hintText: '0300-0000000',
          ),
          validator: (v) {
            final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (clean.length < 10) return 'Please enter a valid contact number';
            return null;
          },
        ),
      ],
    );
  }

  // ── 4. Course Enrollment & 5. Class Mode ────────────────────────────────────
  Widget _buildCourseAndClassModeSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4. COURSE ENROLLMENT Header
          _buildFieldLabel('4. COURSE ENROLLMENT (SELECT DESIRED COURSE) *'),
          const SizedBox(height: 8),

          if (_isLoadingCourses)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
              ),
            )
          else
            ..._availableCourses.map((c) {
              final title = c['title']?.toString() ?? '';
              final fee = (c['fee'] as num?)?.toInt() ?? 0;
              final isSelected = _selectedCourse == title;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCourse = title;
                    _selectedCourseFee = fee;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Rs. ${NumberFormat('#,###').format(fee)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 16),

          // 5. CLASS MODE Header
          _buildFieldLabel('5. CLASS MODE *'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _classMode = 'Online'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _classMode == 'Online' ? const Color(0xFFECFDF5) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _classMode == 'Online' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _classMode == 'Online' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: const Color(0xFF059669),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '💻 Online Live Class (Premier LMS Student App & Portal)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Official Academy Bank Account Details Card ─────────────────────────────
  Widget _buildBankAccountDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B192C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_outlined, color: AppColors.accentGold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Official Academy Bank Account Details',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentGoldLight,
                    ),
                  ),
                ],
              ),
              Text(
                'Total Fee: PKR ${NumberFormat('#,###').format(_selectedCourseFee)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF34D399),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFF1E293B)),

          _buildBankDetailRow('BANK NAME', 'Meezan Bank Limited'),
          const SizedBox(height: 8),
          _buildBankDetailRow('ACCOUNT TITLE', 'Raja Gulfam Tax & Legal Academy'),
          const SizedBox(height: 8),
          _buildBankDetailRow('ACCOUNT NUMBER', '0102030405060708'),
          const SizedBox(height: 8),
          _buildBankDetailRow('IBAN', 'PK92MEZN0001020304050607'),
        ],
      ),
    );
  }

  Widget _buildBankDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ── Payment Method & File Uploads Card ─────────────────────────────────────
  Widget _buildPaymentAndUploadsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PAYMENT METHOD
          _buildFieldLabel('PAYMENT METHOD *'),
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
            decoration: _inputDecoration(),
            items: _paymentMethodOptions
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (val) => setState(() => _paymentMethod = val ?? 'Meezan Bank Transfer'),
          ),
          const SizedBox(height: 14),

          // BANK TRANSACTION / TRX ID
          _buildFieldLabel('BANK TRANSACTION / TRX ID *'),
          TextFormField(
            controller: _transactionIdController,
            style: GoogleFonts.robotoMono(fontSize: 13),
            decoration: _inputDecoration(
              hintText: 'e.g. TRX-98432176',
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Transaction ID is required' : null,
          ),
          const SizedBox(height: 16),

          // PAYMENT RECEIPT / SLIP (MAX 5MB)
          _buildFileUploadRow(
            label: 'PAYMENT RECEIPT / SLIP (MAX 5MB)',
            fileName: _paymentReceiptName,
            onPick: () => _pickFile('receipt'),
          ),
          const SizedBox(height: 14),

          // UPLOAD CNIC / ID FRONT COPY (MAX 5MB)
          _buildFileUploadRow(
            label: 'UPLOAD CNIC / ID FRONT COPY (MAX 5MB)',
            fileName: _cnicFileName,
            onPick: () => _pickFile('cnic'),
          ),
          const SizedBox(height: 14),

          // UPLOAD PASSPORT PHOTOGRAPH (MAX 5MB)
          _buildFileUploadRow(
            label: 'UPLOAD PASSPORT PHOTOGRAPH (MAX 5MB)',
            fileName: _photoFileName,
            onPick: () => _pickFile('photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadRow({
    required String label,
    required String? fileName,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 4),
        Row(
          children: [
            ElevatedButton(
              onPressed: onPick,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFECFDF5),
                foregroundColor: const Color(0xFF059669),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                ),
              ),
              child: Text(
                'Choose File',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName ?? 'No file chosen',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: fileName != null ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                  fontWeight: fileName != null ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Declaration Checkbox ───────────────────────────────────────────────────
  Widget _buildDeclarationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _declarationAgreed,
            activeColor: AppColors.primaryGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) => setState(() => _declarationAgreed = val ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'DECLARATION: I hereby declare that the information provided above is correct to the best of my knowledge and I agree to abide by the rules and regulations of Premier Tax Corporate & Accounting School.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.45,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit Button & SSL Badge ──────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 14, color: Color(0xFF059669)),
            const SizedBox(width: 6),
            Text(
              'SSL Encrypted & Verified Admission Gateway',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    'Submit Online Admission Application',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Success Confirmation Screen ───────────────────────────────────────────
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFA7F3D0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Application Submitted!',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _successMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryLine('Applicant:', _fullNameController.text),
                        _buildSummaryLine('CNIC:', _cnicController.text),
                        _buildSummaryLine('WhatsApp:', _whatsappController.text),
                        _buildSummaryLine('Course:', _selectedCourse),
                        _buildSummaryLine('Status:', 'Pending Fee Verification'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Return to Portal',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    IconData? prefixIcon,
    IconData? suffixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
      helperText: helperText,
      helperStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF94A3B8)) : null,
      suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 20, color: const Color(0xFF94A3B8)) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}
