import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:good_news/core/constants/theme_tokens.dart';
import 'package:good_news/core/services/social_api_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isPosting = false;
  bool _isUploadingImage = false;
  String _visibility = 'Public';
  File? _selectedImageFile;
  String? _uploadedImageUrl;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_updateButtonState);
    _titleController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _textController.removeListener(_updateButtonState);
    _titleController.removeListener(_updateButtonState);
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {});
  }

  bool get _canPost => _textController.text.trim().isNotEmpty && !_isPosting && !_isUploadingImage;

  Future<void> _createPost() async {
    if (!_canPost) return;

    final content = _textController.text.trim();
    final title = _titleController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Content is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      print('📝 CREATE POST: Starting post creation...');
      print('📝 CREATE POST: Title: "$title"');
      print('📝 CREATE POST: Content: "$content"');
      print('📝 CREATE POST: Visibility (UI): "$_visibility"');
      print('📝 CREATE POST: Uploaded Image URL: ${_uploadedImageUrl ?? 'None'}');

      String visibilityFormatted;
      switch (_visibility) {
        case 'Public':
          visibilityFormatted = 'public';
          break;
        case 'Friends Only':
          visibilityFormatted = 'friends';
          break;
        case 'Private':
          visibilityFormatted = 'private';
          break;
        default:
          visibilityFormatted = 'public';
      }

      print('📝 CREATE POST: Visibility (API): "$visibilityFormatted"');

      final response = await SocialApiService.createPost(
        content,
        visibilityFormatted,
        title: title.isNotEmpty ? title : null,
        imageUrl: _uploadedImageUrl,
      );

      print('📝 CREATE POST: Response status: ${response['status']}');
      print('📝 CREATE POST: Response data: $response');

      if (response['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Good news shared! 🌟'),
              backgroundColor: ThemeTokens.primaryGreen,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to create post');
      }
    } catch (e) {
      print('❌ CREATE POST: Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share post: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  void _selectImage() async {
    var cameraStatus = await Permission.camera.status;
    var galleryStatus = await Permission.photos.status;

    if (!galleryStatus.isGranted && Platform.isAndroid) {
      galleryStatus = await Permission.storage.status;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeTokens.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImageFromCamera();
                    },
                    icon: const Icon(Icons.camera_alt, color: ThemeTokens.primaryGreen),
                    label: const Text(
                      'Camera',
                      style: TextStyle(color: ThemeTokens.primaryGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ThemeTokens.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                    icon: const Icon(Icons.photo_library, color: ThemeTokens.primaryGreen),
                    label: const Text(
                      'Gallery',
                      style: TextStyle(color: ThemeTokens.primaryGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ThemeTokens.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Maximum file size: 5MB',
              style: TextStyle(
                color: ThemeTokens.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final cameraPermission = await Permission.camera.request();

      if (cameraPermission.isGranted) {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          await _handleImageSelection(File(image.path));
        }
      } else if (cameraPermission.isPermanentlyDenied) {
        _showPermissionDeniedDialog('Camera');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to take photos'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('📷 Camera error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📷 Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      PermissionStatus galleryPermission = await Permission.photos.request();

      if (galleryPermission.isDenied && Platform.isAndroid) {
        galleryPermission = await Permission.storage.request();
      }

      print('📂 Gallery permission status: $galleryPermission');

      if (galleryPermission.isGranted ||
          galleryPermission.isLimited ||
          galleryPermission.isPermanentlyDenied) {

        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          await _handleImageSelection(File(image.path));
        }
      } else {
        _showPermissionDeniedDialog('Gallery');
      }
    } catch (e) {
      print('📂 Gallery error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📂 Gallery error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleImageSelection(File imageFile) async {
    try {
      print('📸 IMAGE HANDLING: Starting...');
      print('📸 IMAGE HANDLING: File path: ${imageFile.path}');

      if (!await imageFile.exists()) {
        print('❌ IMAGE HANDLING: File does not exist!');
        _showError('Image file not found');
        return;
      }
      print('✅ IMAGE HANDLING: File exists');

      final fileSizeInBytes = await imageFile.length();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      print('📦 IMAGE HANDLING: File size: ${fileSizeInMB.toStringAsFixed(2)} MB');

      if (fileSizeInMB > 5) {
        _showError('Image size must be less than 5MB (Current: ${fileSizeInMB.toStringAsFixed(2)}MB)');
        return;
      }

      setState(() {
        _selectedImageFile = imageFile;
        _isUploadingImage = true;
        _uploadError = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Uploading image...'),
              ],
            ),
            duration: Duration(seconds: 30),
            backgroundColor: ThemeTokens.primaryGreen,
          ),
        );
      }

      print('📤 IMAGE HANDLING: Calling upload API...');
      final uploadResponse = await SocialApiService.uploadPostImage(imageFile);

      print('📤 IMAGE HANDLING: Upload response: $uploadResponse');
      print('📤 IMAGE HANDLING: Response status: ${uploadResponse['status']}');

      if (uploadResponse['status'] == 'success') {
        final imageUrl = uploadResponse['image_url'];

        if (imageUrl == null || imageUrl.toString().isEmpty) {
          throw Exception('No image URL returned from server');
        }

        setState(() {
          _uploadedImageUrl = imageUrl;
          _isUploadingImage = false;
          _uploadError = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Image uploaded successfully!'),
              backgroundColor: ThemeTokens.primaryGreen,
              duration: Duration(seconds: 2),
            ),
          );
        }

        print('✅ IMAGE HANDLING: Upload successful! URL: $_uploadedImageUrl');
      } else {
        final errorMsg = uploadResponse['error'] ?? 'Unknown upload error';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ IMAGE HANDLING: Error: $e');
      print('❌ IMAGE HANDLING: Error type: ${e.runtimeType}');

      setState(() {
        _selectedImageFile = null;
        _uploadedImageUrl = null;
        _isUploadingImage = false;
        _uploadError = e.toString();
      });

      _showError('Upload failed: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $message'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showPermissionDeniedDialog(String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission Required'),
        content: Text('Please grant $permission access in Settings to select photos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _uploadedImageUrl = null;
      _uploadError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ Image removed'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Post'),
        // ✅ REMOVED Post button from AppBar - it's now in the body opposite to ME
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ FIXED LAYOUT: ME (left) + You/Public (middle) + Post Button (right - opposite to ME)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ ME Avatar (bigger) - LEFT SIDE
                CircleAvatar(
                  radius: 36,
                  backgroundColor: colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    'ME',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // ✅ You + Public stacked vertically (MIDDLE)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'You',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButton<String>(
                        value: _visibility,
                        dropdownColor: theme.cardTheme.color ?? colorScheme.surfaceVariant,
                        underline: Container(),
                        isExpanded: true,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        items: ['Public', 'Friends Only', 'Private'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  value == 'Public'
                                      ? Icons.public
                                      : value == 'Friends Only'
                                      ? Icons.people
                                      : Icons.lock,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _visibility = newValue!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const Spacer(), // ✅ PUSHES Post button to the RIGHT
                // ✅ Post Button - EXACTLY OPPOSITE TO ME (RIGHT SIDE)
                ElevatedButton(
                  onPressed: _canPost ? _createPost : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPosting || _isUploadingImage
                        ? colorScheme.secondary
                        : (_canPost ? colorScheme.primary : colorScheme.secondary.withOpacity(0.5)),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                  child: _isPosting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Post',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ✅ Text input with reduced left padding
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: TextField(
                  controller: _textController,
                  maxLines: 8,
                  minLines: 8,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.5,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share something positive that happened today... (Required)',
                    hintStyle: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Show error if upload failed
            if (_uploadError != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Error',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _uploadError!,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            if (_selectedImageFile != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.file(
                              _selectedImageFile!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  _isUploadingImage ? Icons.cloud_upload : Icons.check_circle,
                                  color: _isUploadingImage ? colorScheme.secondary : Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isUploadingImage ? 'Uploading...' : 'Image uploaded',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (!_isUploadingImage)
                                  IconButton(
                                    onPressed: _removeImage,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                    tooltip: 'Remove image',
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_isUploadingImage)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUploadingImage ? null : _selectImage,
                icon: Icon(
                  Icons.photo_camera_outlined,
                  color: _isUploadingImage ? Colors.grey : colorScheme.primary,
                  size: 20,
                ),
                label: Text(
                  _selectedImageFile == null ? 'Add Photo (Optional)' : 'Change Photo',
                  style: textTheme.labelLarge?.copyWith(
                    color: _isUploadingImage ? Colors.grey : colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _isUploadingImage ? Colors.grey : colorScheme.primary,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}