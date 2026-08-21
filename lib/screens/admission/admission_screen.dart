import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Multi-step State (1 to 5)
  int _step = 1;
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _coursesList = [];
  bool _loadingCourses = true;

  // Step 1: Personal Information
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _dobController = TextEditingController();
  String _gender = 'Male';
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();

  // Step 2: Academic Background & Address
  final _lastQualificationController = TextEditingController();
  final _passingYearController = TextEditingController();
  final _instituteController = TextEditingController();
  final _cityController = TextEditingController();
  String _province = 'Punjab';
  final _postalAddressController = TextEditingController();

  // Step 3: Emergency Contact
  final _emergencyNameController = TextEditingController();
  final _emergencyRelationController = TextEditingController(text: 'Guardian');
  final _emergencyContactController = TextEditingController();

  // Step 4: Application Pathway (Course Enrollment vs. Test / Certification Only)
  String _applicationType = 'Course Enrollment'; // 'Course Enrollment' | 'Test / Certification Only'
  String _selectedCourse = 'Certified Tax Practitioner (CTP)';
  static const String _classMode = 'Online Live Class (Premier LMS Student App & Portal)';

  // Test / Certification Only fields
  String _testReason = 'I already have sufficient knowledge of the subject';
  final _otherTestReasonController = TextEditingController();
  final _previousTrainingController = TextEditingController();
  final _professionalExperienceController = TextEditingController();
  static const String _assessmentMode = 'On-site Assessment';
  final _preferredAssessmentDateController = TextEditingController();

  // Payment Method & Details
  String _paymentMethod = 'Bank Transfer'; // 'Bank Transfer' | 'EasyPaisa' | 'JazzCash'
  final _transactionIdController = TextEditingController();
  String? _copiedField;

  // File Uploads
  String _cnicFile = '';
  String _cnicFileSize = '';
  String _photoFile = '';
  String _photoFileSize = '';
  String _paymentProof = '';
  String _paymentProofSize = '';
  final Map<String, String> _fileErrors = {};
  final Map<String, bool> _fileUploading = {};

  // Declarations & Final Confirmations
  bool _courseDeclarationAgreed = true;
  bool _testDeclarationAgreed = true;
  bool _finalConfirmationAgreed = false;

  // Validation Errors
  Map<String, String> _errors = {};

  // Statuses
  bool _submitting = false;
  Map<String, String>? _successData;
  String? _errorMsg;

  // Enrollment status checks
  bool _hasActiveEnrollment = false;
  String _activeCourseName = '';
  bool _checkingStatus = true;

  final ImagePicker _picker = ImagePicker();

  final List<String> _provinceOptions = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Islamabad Capital Territory',
    'Azad Jammu & Kashmir',
    'Gilgit-Baltistan',
  ];

  final List<String> _genderOptions = ['Male', 'Female'];

  final List<String> _testReasonOptions = [
    'I already have sufficient knowledge of the subject',
    'I have completed equivalent training elsewhere',
    'I am self-taught',
    'I have professional experience',
    'I have previously studied this subject',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    // Pre-fill user info if logged in
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn && auth.user != null) {
      _fullNameController.text = auth.user!.name;
      _emailController.text = auth.user!.email;
      if (auth.user!.enrolledCourses.isNotEmpty) {
        _hasActiveEnrollment = true;
        _activeCourseName = auth.user!.enrolledCourses.first;
      }
    }
    _checkingStatus = false;

    _loadCourses();
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
    _lastQualificationController.dispose();
    _passingYearController.dispose();
    _instituteController.dispose();
    _cityController.dispose();
    _postalAddressController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyContactController.dispose();
    _otherTestReasonController.dispose();
    _previousTrainingController.dispose();
    _professionalExperienceController.dispose();
    _preferredAssessmentDateController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final api = ApiService();
      final res = await api.dio.get(ApiConfig.courses);
      final raw = res.data;
      List<dynamic> fetched = [];
      if (raw is List) {
        fetched = raw;
      } else if (raw is Map && raw['data'] is List) {
        fetched = raw['data'];
      }

      if (fetched.isNotEmpty) {
        final parsed = fetched.map((c) {
          final map = c as Map<String, dynamic>;
          return {
            'id': map['id']?.toString() ?? '',
            'name': map['name'] ?? map['title'] ?? '',
            'discountedFee': (map['discountedFee'] ?? map['price'] ?? 30000) as num,
          };
        }).toList();

        if (mounted) {
          setState(() {
            _coursesList = parsed;
            if (!_coursesList.any((c) => c['name'] == _selectedCourse)) {
              _selectedCourse = _coursesList.first['name'] as String;
            }
            _loadingCourses = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingCourses = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCourses = false);
    }
  }

  int get _currentFee {
    final found = _coursesList.firstWhere(
      (c) => c['name'] == _selectedCourse,
      orElse: () => {'discountedFee': 30000},
    );
    return (found['discountedFee'] as num).toInt();
  }

  // CNIC Auto-formatter: xxxxx-xxxxxxx-x (13 digits)
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
    if (_errors.containsKey('cnic')) {
      setState(() => _errors.remove('cnic'));
    }
  }

  // Phone Auto-formatter: 03xx-xxxxxxx (11 digits)
  void _onPhoneChanged(TextEditingController controller, String key, String value) {
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
    if (_errors.containsKey(key)) {
      setState(() => _errors.remove(key));
    }
  }

  Future<void> _pickDate({required TextEditingController controller, required String key, bool isDob = false}) async {
    final now = DateTime.now();
    final initialDate = isDob ? DateTime(now.year - 20, 1, 1) : now;
    final firstDate = isDob ? DateTime(1950) : now;
    final lastDate = isDob ? now : DateTime(now.year + 2);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
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
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
        _errors.remove(key);
      });
    }
  }

  void _copyToClipboard(String text, String fieldName) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedField = fieldName);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _copiedField = null);
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 Bytes';
    const suffixes = ['Bytes', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    final size = bytes / pow(1024, i);
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _handleFileUpload(String fieldKey) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (file == null) return;

      final length = await file.length();
      if (length > 5 * 1024 * 1024) {
        setState(() {
          _fileErrors[fieldKey] =
              'File "${file.name}" exceeds 5MB limit (${_formatBytes(length)}). Please upload a smaller file.';
        });
        return;
      }

      setState(() {
        _fileUploading[fieldKey] = true;
        _fileErrors.remove(fieldKey);
        _errors.remove(fieldKey);
      });

      final api = ApiService();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
        ),
      });

      final res = await api.dio.post(ApiConfig.uploads, data: formData);
      final filename = res.data['filename']?.toString() ?? file.name;
      final sizeFormatted = _formatBytes(length);

      setState(() {
        if (fieldKey == 'paymentProof') {
          _paymentProof = filename;
          _paymentProofSize = sizeFormatted;
        } else if (fieldKey == 'cnicFile') {
          _cnicFile = filename;
          _cnicFileSize = sizeFormatted;
        } else if (fieldKey == 'photoFile') {
          _photoFile = filename;
          _photoFileSize = sizeFormatted;
        }
        _fileUploading[fieldKey] = false;
      });
    } catch (err) {
      setState(() {
        _fileUploading[fieldKey] = false;
        _fileErrors[fieldKey] = 'Upload failed. Please try again.';
      });
    }
  }

  void _removeFile(String fieldKey) {
    setState(() {
      if (fieldKey == 'paymentProof') {
        _paymentProof = '';
        _paymentProofSize = '';
      } else if (fieldKey == 'cnicFile') {
        _cnicFile = '';
        _cnicFileSize = '';
      } else if (fieldKey == 'photoFile') {
        _photoFile = '';
        _photoFileSize = '';
      }
    });
  }

  void _viewFilePreview(String name, String filename) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.insert_drive_file, size: 48, color: AppColors.primaryGreen),
                  const SizedBox(height: 8),
                  Text(
                    filename,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attached successfully to application draft.',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _validateStep(int currentStep) {
    final newErrors = <String, String>{};

    if (currentStep == 1) {
      if (_fullNameController.text.trim().length < 3) {
        newErrors['fullName'] = 'Full Name (as per CNIC) is required.';
      }
      if (_fatherNameController.text.trim().length < 3) {
        newErrors['fatherName'] = "Father's / Guardian's Name is required.";
      }
      final cleanCnic = _cnicController.text.replaceAll(RegExp(r'\D'), '');
      if (cleanCnic.length != 13) {
        newErrors['cnic'] = 'Please enter a valid 13-digit Pakistani CNIC number.';
      }
      if (_dobController.text.trim().isEmpty) {
        newErrors['dateOfBirth'] = 'Please select your Date of Birth.';
      }
      final cleanPhone = _whatsappController.text.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length != 11 || !cleanPhone.startsWith('03')) {
        newErrors['whatsapp'] = 'Please enter a valid 11-digit Pakistani mobile number (03xx-xxxxxxx).';
      }
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailRegex.hasMatch(_emailController.text.trim())) {
        newErrors['email'] = 'Please enter a valid email address.';
      }
    }

    if (currentStep == 2) {
      if (_lastQualificationController.text.trim().isEmpty) {
        newErrors['lastQualification'] = 'Last qualification is required.';
      }
      if (_passingYearController.text.trim().isEmpty) {
        newErrors['passingYear'] = 'Passing year is required.';
      }
      if (_instituteController.text.trim().isEmpty) {
        newErrors['institute'] = 'Institute / University name is required.';
      }
      if (_cityController.text.trim().isEmpty) {
        newErrors['city'] = 'City name is required.';
      }
      if (_postalAddressController.text.trim().isEmpty) {
        newErrors['postalAddress'] = 'Complete postal address is required.';
      }
    }

    if (currentStep == 3) {
      if (_emergencyNameController.text.trim().isEmpty) {
        newErrors['emergencyName'] = 'Emergency contact name is required.';
      }
      if (_emergencyRelationController.text.trim().isEmpty) {
        newErrors['emergencyRelation'] = 'Relation is required.';
      }
      final cleanEPhone = _emergencyContactController.text.replaceAll(RegExp(r'\D'), '');
      if (cleanEPhone.length != 11 || !cleanEPhone.startsWith('03')) {
        newErrors['emergencyContact'] = 'Please enter a valid emergency mobile number (03xx-xxxxxxx).';
      }
    }

    if (currentStep == 4) {
      if (_selectedCourse.isEmpty) {
        newErrors['selectedCourse'] = 'Please select a course / certification.';
      }
      if (_applicationType == 'Test / Certification Only') {
        if (_testReason == 'Other' && _otherTestReasonController.text.trim().isEmpty) {
          newErrors['otherTestReason'] = 'Please specify your reason for test-only assessment.';
        }
        if (!_testDeclarationAgreed) {
          newErrors['testDeclaration'] = 'You must agree to the Test/Certification declaration to proceed.';
        }
      } else {
        if (!_courseDeclarationAgreed) {
          newErrors['courseDeclaration'] = 'You must agree to the course rules & declaration to proceed.';
        }
      }
      if (_transactionIdController.text.trim().isEmpty) {
        newErrors['transactionId'] = 'Please enter the $_paymentMethod transaction / reference ID.';
      }
      if (_paymentProof.isEmpty) {
        newErrors['paymentProof'] = 'Please upload your payment screenshot or receipt.';
      }
      if (_cnicFile.isEmpty) {
        newErrors['cnicFile'] = 'Please upload a copy of your CNIC / ID Front.';
      }
      if (_photoFile.isEmpty) {
        newErrors['photoFile'] = 'Please upload a passport-size photograph.';
      }
    }

    setState(() => _errors = newErrors);

    if (newErrors.isNotEmpty) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return false;
    }
    return true;
  }

  void _handleNextStep() {
    if (_validateStep(_step)) {
      setState(() => _step = (_step + 1).clamp(1, 5));
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _handlePrevStep() {
    setState(() => _step = (_step - 1).clamp(1, 5));
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _jumpToStep(int targetStep) {
    setState(() => _step = targetStep);
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _handleSubmitFinal() async {
    setState(() => _errorMsg = null);

    if (!_finalConfirmationAgreed) {
      setState(() => _errorMsg = 'Please confirm that all information provided is correct before submitting.');
      return;
    }

    setState(() => _submitting = true);

    // Generate random reference ID (PTA-2026-XXXXXX)
    final randomNum = 100000 + Random().nextInt(900000);
    final refNum = 'PTA-2026-$randomNum';

    try {
      final api = ApiService();
      final payload = {
        'fullName': _fullNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'gender': _gender,
        'whatsapp': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'postalAddress': '${_postalAddressController.text.trim()}, ${_cityController.text.trim()}, $_province',
        'lastQualification': _lastQualificationController.text.trim(),
        'passingYear': _passingYearController.text.trim(),
        'institute': _instituteController.text.trim(),
        'emergencyName': _emergencyNameController.text.trim(),
        'emergencyRelation': _emergencyRelationController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'applicationType': _applicationType,
        'selectedCourses': [_selectedCourse],
        'classMode': _applicationType == 'Course Enrollment' ? _classMode : 'N/A (Test Only)',
        if (_applicationType == 'Test / Certification Only') ...{
          'testReason': _testReason == 'Other' ? _otherTestReasonController.text.trim() : _testReason,
          'previousTraining': _previousTrainingController.text.trim(),
          'professionalExperience': _professionalExperienceController.text.trim(),
          'assessmentMode': _assessmentMode,
          'preferredAssessmentDate': _preferredAssessmentDateController.text.trim(),
        },
        'totalAmount': _currentFee,
        'paymentMethod': _paymentMethod,
        'transactionId': _transactionIdController.text.trim(),
        'paymentProof': _paymentProof.isNotEmpty ? _paymentProof : 'receipt_submitted.png',
        'cnicFile': _cnicFile.isNotEmpty ? _cnicFile : 'cnic_submitted.pdf',
        'photoFile': _photoFile.isNotEmpty ? _photoFile : 'passport_photo.jpg',
        'referenceId': refNum,
      };

      await api.dio.post(ApiConfig.admissions, data: payload);

      if (mounted) {
        setState(() {
          _successData = {
            'referenceId': refNum,
            'msg':
                'Your application has been received! Our admissions department will review your application. Upon approval, your credentials will be sent to ${_emailController.text.trim()}.',
          };
        });
      }
    } catch (e) {
      String errText = 'Failed to submit application. Please check your information and try again.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          errText = data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString();
        }
      }
      if (mounted) {
        setState(() => _errorMsg = errText);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingStatus) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (_hasActiveEnrollment) {
      return _buildAlreadyEnrolledScreen();
    }

    if (_successData != null) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Online Admission Portal',
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
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                _buildHeaderBanner(),
                const SizedBox(height: 16),

                // Multi-step Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Stepper Navigation Header
                      _buildStepperHeader(),

                      // Error Banner if present
                      if (_errorMsg != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C)),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            if (_step == 1) _buildStep1Personal(),
                            if (_step == 2) _buildStep2Academic(),
                            if (_step == 3) _buildStep3Emergency(),
                            if (_step == 4) _buildStep4ApplicationAndPayment(),
                            if (_step == 5) _buildStep5Review(),

                            const SizedBox(height: 24),
                            const Divider(color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 16),

                            // Stepper Controls Footer
                            _buildStepperControls(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, size: 14, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Text(
                'Official Student Admission & Certification Portal',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF065F46),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Online Admission Application Form',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Instructed directly by Advocate High Court & ACMA Raja Gulfam Kayani. Enroll in complete masterclasses or apply directly for certification assessments.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildStepperHeader() {
    final steps = [
      {'num': 1, 'title': 'Personal'},
      {'num': 2, 'title': 'Academic'},
      {'num': 3, 'title': 'Emergency'},
      {'num': 4, 'title': 'Application'},
      {'num': 5, 'title': 'Review'},
    ];

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.map((s) {
              final stepNum = s['num'] as int;
              final isCurrent = _step == stepNum;
              final isCompleted = _step > stepNum;

              return Expanded(
                child: GestureDetector(
                  onTap: isCompleted ? () => _jumpToStep(stepNum) : null,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? AppColors.primaryGreen
                              : (isCompleted ? const Color(0xFF059669) : const Color(0xFF1E293B)),
                          border: Border.all(
                            color: isCurrent
                                ? Colors.white.withValues(alpha: 0.5)
                                : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF334155)),
                          ),
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text(
                                  '$stepNum',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? Colors.white : const Color(0xFF94A3B8),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? const Color(0xFF34D399)
                              : (isCompleted ? Colors.white : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Progress bar line
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _step / 5.0,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Personal Information ──────────────────────────────────────────
  Widget _buildStep1Personal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading('Step 1: Personal Information', 'Required for official diploma registration & student records.'),
        const SizedBox(height: 16),

        _buildTextField(
          controller: _fullNameController,
          label: 'Full Name (As per CNIC) *',
          hint: 'e.g. Muhammad Ali Khan',
          icon: Icons.person_outline,
          error: _errors['fullName'],
          onChanged: (val) => _errors.remove('fullName'),
        ),
        const SizedBox(height: 14),

        _buildTextField(
          controller: _fatherNameController,
          label: "Father's / Guardian's Name *",
          hint: 'e.g. Tariq Mehmood Khan',
          icon: Icons.person_outline,
          error: _errors['fatherName'],
          onChanged: (val) => _errors.remove('fatherName'),
        ),
        const SizedBox(height: 14),

        _buildTextField(
          controller: _cnicController,
          label: 'Pakistani CNIC Number * (13 Digits)',
          hint: '37405-1234567-1',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          error: _errors['cnic'],
          helper: 'Format: 13 digits (Auto-hyphenated)',
          onChanged: _onCnicChanged,
        ),
        const SizedBox(height: 14),

        // DOB & Gender Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(controller: _dobController, key: 'dateOfBirth', isDob: true),
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _dobController,
                    label: 'Date of Birth *',
                    hint: 'YYYY-MM-DD',
                    icon: Icons.calendar_today_outlined,
                    error: _errors['dateOfBirth'],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gender *',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _gender,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        items: _genderOptions
                            .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g, style: GoogleFonts.inter(fontSize: 12)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _gender = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildTextField(
          controller: _whatsappController,
          label: 'Pakistani Mobile / WhatsApp Contact *',
          hint: '0300-1234567',
          icon: Icons.phone_android_outlined,
          keyboardType: TextInputType.phone,
          error: _errors['whatsapp'],
          helper: '11 digits starting with 03',
          onChanged: (val) => _onPhoneChanged(_whatsappController, 'whatsapp', val),
        ),
        const SizedBox(height: 14),

        _buildTextField(
          controller: _emailController,
          label: 'Email Address *',
          hint: 'name@domain.com',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          error: _errors['email'],
          onChanged: (val) => _errors.remove('email'),
        ),
      ],
    );
  }

  // ── Step 2: Academic & Address ────────────────────────────────────────────
  Widget _buildStep2Academic() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading('Step 2: Academic Background & Address', 'Enter your highest education details and certificate dispatch address.'),
        const SizedBox(height: 16),

        _buildSectionHeaderTag(Icons.school_outlined, 'Academic Qualification'),
        const SizedBox(height: 12),

        _buildTextField(
          controller: _lastQualificationController,
          label: 'Last Qualification *',
          hint: 'e.g. B.Com, LL.B, CA, MBA',
          icon: Icons.school_outlined,
          error: _errors['lastQualification'],
          onChanged: (val) => _errors.remove('lastQualification'),
        ),
        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _passingYearController,
                label: 'Passing Year *',
                hint: 'e.g. 2023',
                icon: Icons.event_outlined,
                keyboardType: TextInputType.number,
                error: _errors['passingYear'],
                onChanged: (val) => _errors.remove('passingYear'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _buildTextField(
                controller: _instituteController,
                label: 'Institute / University *',
                hint: 'e.g. University of the Punjab',
                icon: Icons.account_balance_outlined,
                error: _errors['institute'],
                onChanged: (val) => _errors.remove('institute'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _buildSectionHeaderTag(Icons.location_on_outlined, 'Dispatch & Postal Address'),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller: _cityController,
                label: 'City Name *',
                hint: 'e.g. Lahore, Karachi',
                icon: Icons.location_city_outlined,
                error: _errors['city'],
                onChanged: (val) => _errors.remove('city'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Province *',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _province,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        items: _provinceOptions
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p, style: GoogleFonts.inter(fontSize: 11), overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _province = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildTextField(
          controller: _postalAddressController,
          label: 'Complete Postal Address *',
          hint: 'House/Office No., Street, Sector/Area',
          icon: Icons.markunread_mailbox_outlined,
          maxLines: 2,
          error: _errors['postalAddress'],
          onChanged: (val) => _errors.remove('postalAddress'),
        ),
      ],
    );
  }

  // ── Step 3: Emergency Contact ─────────────────────────────────────────────
  Widget _buildStep3Emergency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading('Step 3: Emergency Contact Information', 'Used only if the academy needs to contact your emergency contact.'),
        const SizedBox(height: 16),

        _buildTextField(
          controller: _emergencyNameController,
          label: 'Emergency Contact Name *',
          hint: 'e.g. Tariq Mehmood',
          icon: Icons.person_pin_outlined,
          error: _errors['emergencyName'],
          onChanged: (val) => _errors.remove('emergencyName'),
        ),
        const SizedBox(height: 14),

        _buildTextField(
          controller: _emergencyRelationController,
          label: 'Relation *',
          hint: 'e.g. Father / Brother / Spouse',
          icon: Icons.family_restroom_outlined,
          error: _errors['emergencyRelation'],
          onChanged: (val) => _errors.remove('emergencyRelation'),
        ),
        const SizedBox(height: 14),

        _buildTextField(
          controller: _emergencyContactController,
          label: 'Emergency Contact Number *',
          hint: '0300-0000000',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          error: _errors['emergencyContact'],
          helper: '11 digits starting with 03',
          onChanged: (val) => _onPhoneChanged(_emergencyContactController, 'emergencyContact', val),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Privacy Guarantee: Emergency contact information is strictly confidential and will only be accessed in urgent administrative scenarios.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF92400E), height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 4: Application Pathway & Payment ─────────────────────────────────
  Widget _buildStep4ApplicationAndPayment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading('Step 4: Application & Payment', 'Choose your pathway, select course, payment method, and upload proof.'),
        const SizedBox(height: 16),

        Text(
          'How would you like to proceed? *',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),

        // Pathway Selection Cards (Course Enrollment vs Test / Certification Only)
        Row(
          children: [
            Expanded(
              child: _buildPathwayCard(
                type: 'Course Enrollment',
                title: 'Option 1: Course Enrollment',
                subtitle: 'Enroll in the complete course',
                description: 'Attend live classes, access recorded lectures, materials, and complete full diploma.',
                icon: Icons.menu_book,
                iconColor: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPathwayCard(
                type: 'Test / Certification Only',
                title: 'Option 2: Test / Certification Only',
                subtitle: 'Already know the subject?',
                description: 'Apply directly for assessment and certification without complete course lectures.',
                icon: Icons.workspace_premium,
                iconColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Conditional Pathway Form Content
        if (_applicationType == 'Course Enrollment')
          _buildCourseEnrollmentDetails()
        else
          _buildTestOnlyDetails(),

        const SizedBox(height: 20),
        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 16),

        // Payment Method Selector Cards
        Text(
          'Select Payment Method *',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(
          'Select how you transferred your fee to the academy.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildPaymentMethodCard(
                method: 'Bank Transfer',
                subtitle: 'Meezan Bank',
                icon: Icons.account_balance,
                iconColor: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPaymentMethodCard(
                method: 'EasyPaisa',
                subtitle: 'Mobile Wallet',
                icon: Icons.phone_android,
                iconColor: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPaymentMethodCard(
                method: 'JazzCash',
                subtitle: 'Mobile Wallet',
                icon: Icons.credit_card,
                iconColor: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Dynamic Payment Instructions Card (Dark Slate)
        _buildPaymentInstructionsCard(),
        const SizedBox(height: 16),

        // Transaction ID
        _buildTextField(
          controller: _transactionIdController,
          label: 'Transaction / Reference ID *',
          hint: _paymentMethod == 'Bank Transfer'
              ? 'Enter bank TRX ID (e.g. TRX-98432176)'
              : 'Enter $_paymentMethod reference ID',
          icon: Icons.receipt_long_outlined,
          error: _errors['transactionId'],
          onChanged: (val) => _errors.remove('transactionId'),
        ),
        const SizedBox(height: 16),

        // Document Upload Cards (Payment Proof, CNIC Front, Photo)
        Text(
          'Upload Verification Documents *',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),

        _buildFileUploadTile(
          fieldKey: 'paymentProof',
          label: 'Payment Proof *',
          description: 'Upload screenshot, receipt, or transaction slip. (Max 5MB)',
          filename: _paymentProof,
          filesize: _paymentProofSize,
          error: _errors['paymentProof'] ?? _fileErrors['paymentProof'],
        ),
        const SizedBox(height: 10),

        _buildFileUploadTile(
          fieldKey: 'cnicFile',
          label: 'CNIC / ID Front Copy *',
          description: 'Upload clear front image of CNIC/ID. (Max 5MB)',
          filename: _cnicFile,
          filesize: _cnicFileSize,
          error: _errors['cnicFile'] ?? _fileErrors['cnicFile'],
        ),
        const SizedBox(height: 10),

        _buildFileUploadTile(
          fieldKey: 'photoFile',
          label: 'Passport Photograph *',
          description: 'Upload recent passport-size photo. (Max 5MB)',
          filename: _photoFile,
          filesize: _photoFileSize,
          error: _errors['photoFile'] ?? _fileErrors['photoFile'],
        ),
        const SizedBox(height: 16),

        // Payment Summary Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAYMENT SUMMARY',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF065F46)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('Pathway', _applicationType),
                  _buildSummaryItem('Method', _paymentMethod),
                  _buildSummaryItem('Amount', 'PKR ${_currentFee.toString()}'),
                  _buildSummaryItem('Proof', _paymentProof.isNotEmpty ? '✓ Attached' : 'Pending'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseEnrollmentDetails() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COURSE SELECTION',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF065F46)),
              ),
              Text(
                'Fee: PKR $_currentFee',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_loadingCourses)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else
            Column(
              children: _coursesList.map((c) {
                final name = c['name'] as String;
                final fee = (c['discountedFee'] as num).toInt();
                final isSelected = _selectedCourse == name;

                return GestureDetector(
                  onTap: () => setState(() => _selectedCourse = name),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryGreen : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          'Rs. $fee',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 10),

          // Class Mode Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.laptop_chromebook, size: 16, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _classMode,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Course Declaration Checkbox
          CheckboxListTile(
            value: _courseDeclarationAgreed,
            activeColor: AppColors.primaryGreen,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'DECLARATION: I hereby declare that the information provided above is correct to the best of my knowledge and I agree to abide by the rules and regulations of Premier Tax Corporate & Accounting School.',
              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF334155), height: 1.3),
            ),
            onChanged: (val) {
              setState(() {
                _courseDeclarationAgreed = val ?? false;
                if (_courseDeclarationAgreed) _errors.remove('courseDeclaration');
              });
            },
          ),
          if (_errors.containsKey('courseDeclaration'))
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(_errors['courseDeclaration']!, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildTestOnlyDetails() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text(
                'Already know the material?',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'If you already have sufficient knowledge, previous training, or professional experience, you may apply directly for assessment without enrolling in the complete course.',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF78350F), height: 1.3),
          ),
          const SizedBox(height: 12),

          // Course dropdown for test-only
          Text('Select Certification / Course *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCourse,
                isExpanded: true,
                items: _coursesList
                    .map((c) => DropdownMenuItem(
                          value: c['name'] as String,
                          child: Text('${c['name']} — Rs. ${c['discountedFee']}', style: GoogleFonts.inter(fontSize: 11)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCourse = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Reason dropdown
          Text('Reason for test-only assessment *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _testReason,
                isExpanded: true,
                items: _testReasonOptions
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: GoogleFonts.inter(fontSize: 11), overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _testReason = val);
                },
              ),
            ),
          ),

          if (_testReason == 'Other') ...[
            const SizedBox(height: 10),
            _buildTextField(
              controller: _otherTestReasonController,
              label: 'Please specify reason *',
              hint: 'Describe your reason',
              icon: Icons.edit_note,
              error: _errors['otherTestReason'],
              onChanged: (val) => _errors.remove('otherTestReason'),
            ),
          ],
          const SizedBox(height: 12),

          _buildTextField(
            controller: _previousTrainingController,
            label: 'Previous Training / Qualification (Optional)',
            hint: 'Describe relevant training or certifications',
            icon: Icons.history_edu,
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _professionalExperienceController,
            label: 'Relevant Professional Experience (Optional)',
            hint: 'Describe your practical experience',
            icon: Icons.work_outline,
          ),
          const SizedBox(height: 12),

          // Preferred Assessment Date
          GestureDetector(
            onTap: () => _pickDate(controller: _preferredAssessmentDateController, key: 'preferredAssessmentDate'),
            child: AbsorbPointer(
              child: _buildTextField(
                controller: _preferredAssessmentDateController,
                label: 'Preferred Assessment Date (Optional)',
                hint: 'YYYY-MM-DD',
                icon: Icons.calendar_month_outlined,
                helper: 'Subject to academy approval and seat availability.',
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Test Declaration Checkbox
          CheckboxListTile(
            value: _testDeclarationAgreed,
            activeColor: AppColors.primaryGreen,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'TEST / CERTIFICATION DECLARATION: I confirm that I am applying for assessment & certification only. I understand certification is subject to successfully passing the required on-site examination.',
              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF334155), height: 1.3),
            ),
            onChanged: (val) {
              setState(() {
                _testDeclarationAgreed = val ?? false;
                if (_testDeclarationAgreed) _errors.remove('testDeclaration');
              });
            },
          ),
          if (_errors.containsKey('testDeclaration'))
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(_errors['testDeclaration']!, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildPathwayCard({
    required String type,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _applicationType == type;

    return GestureDetector(
      onTap: () => setState(() => _applicationType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primaryGreen.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: iconColor.withValues(alpha: 0.15),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected ? AppColors.primaryGreen : const Color(0xFF94A3B8),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF065F46) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B), height: 1.25),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required String method,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _paymentMethod == method;

    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 6),
            Text(
              method,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _paymentMethod == 'Bank Transfer'
                    ? '🏦 Bank Transfer Account Details'
                    : '📱 $_paymentMethod Account Details',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFFBBF24)),
              ),
              Text(
                'Amount: PKR $_currentFee',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 8),

          if (_paymentMethod == 'Bank Transfer') ...[
            _buildCopyRow('Bank Name', 'Meezan Bank Limited', null),
            _buildCopyRow('Account Title', 'Raja Gulfam Tax & Legal Academy', null),
            _buildCopyRow('Account Number', '0102030405060708', 'accNum'),
            _buildCopyRow('IBAN', 'PK92MEZN0001020304050607', 'iban'),
          ] else if (_paymentMethod == 'EasyPaisa') ...[
            _buildCopyRow('Account Name', 'Raja Gulfam Tax & Legal Academy', null),
            _buildCopyRow('EasyPaisa Number', '0334-8972072', 'epNum', copyValue: '03348972072'),
          ] else ...[
            _buildCopyRow('Account Name', 'Raja Gulfam Tax & Legal Academy', null),
            _buildCopyRow('JazzCash Number', '0334-8972072', 'jcNum', copyValue: '03348972072'),
          ],
        ],
      ),
    );
  }

  Widget _buildCopyRow(String label, String value, String? fieldKey, {String? copyValue}) {
    final isCopied = _copiedField == fieldKey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8))),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: fieldKey != null ? const Color(0xFF6EE7B7) : Colors.white,
                ),
              ),
            ],
          ),
          if (fieldKey != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCopied ? AppColors.primaryGreen : const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(isCopied ? Icons.check : Icons.copy, size: 12),
              label: Text(isCopied ? 'Copied' : 'Copy', style: GoogleFonts.inter(fontSize: 10)),
              onPressed: () => _copyToClipboard(copyValue ?? value, fieldKey),
            ),
        ],
      ),
    );
  }

  Widget _buildFileUploadTile({
    required String fieldKey,
    required String label,
    required String description,
    required String filename,
    required String filesize,
    String? error,
  }) {
    final isUploading = _fileUploading[fieldKey] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: error != null ? Colors.red : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
              Text('Max 5MB', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 2),
          Text(description, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 8),

          if (isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Uploading to server...', style: TextStyle(fontSize: 11)),
                ],
              ),
            )
          else if (filename.isEmpty)
            OutlinedButton.icon(
              onPressed: () => _handleFileUpload(fieldKey),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: Color(0xFFCBD5E1), style: BorderStyle.solid),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              icon: const Icon(Icons.cloud_upload_outlined, size: 16),
              label: Text('Browse Image / Document', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      filename,
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(filesize, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _viewFilePreview(label, filename),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.visibility_outlined, size: 14, color: AppColors.primaryGreen),
                    ),
                  ),
                  InkWell(
                    onTap: () => _removeFile(fieldKey),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline, size: 14, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          if (error != null) ...[
            const SizedBox(height: 4),
            Text(error, style: GoogleFonts.inter(fontSize: 10, color: Colors.red)),
          ],
        ],
      ),
    );
  }

  // ── Step 5: Review & Submit ───────────────────────────────────────────────
  Widget _buildStep5Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading('Review Your Application', 'Carefully review all information before final submission. Tap "Edit" on any section to make changes.'),
        const SizedBox(height: 16),

        _buildReviewCard(
          stepNum: 1,
          icon: Icons.person_outline,
          title: 'Personal Information',
          items: {
            'Full Name': _fullNameController.text.trim(),
            'Father / Guardian': _fatherNameController.text.trim(),
            'CNIC': _cnicController.text.trim(),
            'DOB': _dobController.text.trim(),
            'Gender': _gender,
            'Mobile': _whatsappController.text.trim(),
            'Email': _emailController.text.trim(),
          },
        ),
        const SizedBox(height: 12),

        _buildReviewCard(
          stepNum: 2,
          icon: Icons.school_outlined,
          title: 'Academic & Address',
          items: {
            'Qualification': _lastQualificationController.text.trim(),
            'Passing Year': _passingYearController.text.trim(),
            'Institute': _instituteController.text.trim(),
            'City': _cityController.text.trim(),
            'Province': _province,
            'Address': _postalAddressController.text.trim(),
          },
        ),
        const SizedBox(height: 12),

        _buildReviewCard(
          stepNum: 3,
          icon: Icons.phone_outlined,
          title: 'Emergency Contact',
          items: {
            'Name': _emergencyNameController.text.trim(),
            'Relation': _emergencyRelationController.text.trim(),
            'Contact': _emergencyContactController.text.trim(),
          },
        ),
        const SizedBox(height: 12),

        _buildReviewCard(
          stepNum: 4,
          icon: Icons.menu_book,
          title: 'Application Pathway & Details',
          items: {
            'Pathway': _applicationType,
            'Course': _selectedCourse,
            'Fee': 'PKR $_currentFee',
            if (_applicationType == 'Course Enrollment')
              'Class Mode': _classMode
            else ...{
              'Reason': _testReason == 'Other' ? _otherTestReasonController.text.trim() : _testReason,
              'Assessment Mode': _assessmentMode,
              if (_preferredAssessmentDateController.text.isNotEmpty)
                'Preferred Date': _preferredAssessmentDateController.text.trim(),
            },
          },
        ),
        const SizedBox(height: 12),

        _buildReviewCard(
          stepNum: 4,
          icon: Icons.credit_card,
          title: 'Payment & Uploaded Documents',
          items: {
            'Payment Method': _paymentMethod,
            'Transaction ID': _transactionIdController.text.trim(),
            'Payment Proof': _paymentProof.isNotEmpty ? '✓ Attached' : 'Missing',
            'CNIC Copy': _cnicFile.isNotEmpty ? '✓ Attached' : 'Missing',
            'Photo': _photoFile.isNotEmpty ? '✓ Attached' : 'Missing',
          },
        ),
        const SizedBox(height: 16),

        // Ready to submit card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to Submit?',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'Please confirm the declaration below before submitting your official application.',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 10),

              CheckboxListTile(
                value: _finalConfirmationAgreed,
                activeColor: AppColors.primaryGreen,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'FINAL CONFIRMATION: I confirm that all information provided above is correct and verified. I understand that false or misleading details may lead to cancellation of my registration.',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white, height: 1.3),
                ),
                onChanged: (val) {
                  setState(() => _finalConfirmationAgreed = val ?? false);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard({
    required int stepNum,
    required IconData icon,
    required String title,
    required Map<String, String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton.icon(
                onPressed: () => _jumpToStep(stepNum),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.primaryGreen,
                ),
                icon: const Icon(Icons.edit, size: 12),
                label: Text('Edit', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 8),

          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: items.entries.map((e) {
              return SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8))),
                    Text(
                      e.value.isNotEmpty ? e.value : '—',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Stepper Controls ──────────────────────────────────────────────────────
  Widget _buildStepperControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_step > 1)
          OutlinedButton.icon(
            onPressed: _handlePrevStep,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text('Back', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
          )
        else
          const SizedBox.shrink(),

        if (_step < 5)
          ElevatedButton.icon(
            onPressed: _handleNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            label: Text('Continue', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.arrow_forward, size: 16),
          )
        else
          ElevatedButton.icon(
            onPressed: _submitting || !_finalConfirmationAgreed ? null : _handleSubmitFinal,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _submitting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.lock, size: 16),
            label: Text(
              _submitting
                  ? 'Submitting...'
                  : (_applicationType == 'Course Enrollment'
                      ? 'Submit Admission Application'
                      : 'Submit Assessment Application'),
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _buildStepHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildSectionHeaderTag(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryGreen),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF065F46)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? error,
    String? helper,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error != null ? Colors.red : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
            ),
          ),
        ),
        if (helper != null && error == null)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4),
            child: Text(helper, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4),
            child: Text(error, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.red)),
          ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF065F46))),
        Text(
          val,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF064E3B)),
        ),
      ],
    );
  }

  // ── Success Confirmation Screen ───────────────────────────────────────────
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Application Submitted'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFA7F3D0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFFD1FAE5),
                    child: Icon(Icons.check_circle, size: 48, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Application Submitted Successfully',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Thank you, ${_fullNameController.text.trim()}. ${_successData!['msg']}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('APPLICATION REFERENCE', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                            Text(
                              _successData!['referenceId']!,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryGreen),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildSuccessRow('Applicant Name', _fullNameController.text.trim()),
                        _buildSuccessRow('Application Type', _applicationType),
                        _buildSuccessRow('Course / Certification', _selectedCourse),
                        _buildSuccessRow('Status', 'Application Received'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'The academy will review your application and payment proof. You will receive updates via WhatsApp (${_whatsappController.text}) and Email (${_emailController.text}).',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
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
                      child: Text('Back to Home', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget _buildSuccessRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          Text(val, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildAlreadyEnrolledScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Admission Status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 54, color: Color(0xFFF59E0B)),
                const SizedBox(height: 16),
                Text('Already Enrolled', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'You are currently enrolled in $_activeCourseName on the Premier LMS Student App.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                  child: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
