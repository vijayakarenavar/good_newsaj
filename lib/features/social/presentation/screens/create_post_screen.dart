// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:good_news/core/constants/theme_tokens.dart';
// import 'package:good_news/core/services/social_api_service.dart';
//
// class CreatePostScreen extends StatefulWidget {
//   const CreatePostScreen({Key? key}) : super(key: key);
//
//   @override
//   State<CreatePostScreen> createState() => _CreatePostScreenState();
// }
//
// class _CreatePostScreenState extends State<CreatePostScreen> {
//   final TextEditingController _textController = TextEditingController();
//   final TextEditingController _titleController = TextEditingController();final ImagePicker _picker = ImagePicker();
//   bool _isPosting = false;
//   bool _isUploadingImage = false;
//   String _visibility = 'Public';
//   File? _selectedImageFile;
//   String? _uploadedImageUrl;
//   String? _uploadError;
//
//   @override
//   void initState() {
//     super.initState();
//     _textController.addListener(_updateButtonState);
//     _titleController.addListener(_updateButtonState);
//   }
//
//   @override
//   void dispose() {
//     _textController.removeListener(_updateButtonState);
//     _titleController.removeListener(_updateButtonState);
//     _textController.dispose();
//     _titleController.dispose();
//     super.dispose();
//   }
//
//   void _updateButtonState() {
//     setState(() {});
//   }
//
//   bool get _canPost => _textController.text.trim().isNotEmpty && !_isPosting && !_isUploadingImage;
//
//   Future<void> _createPost() async {
//     if (!_canPost) return;
//
//     final content = _textController.text.trim();
//     final title = _titleController.text.trim();
//
//     if (content.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Content is required'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
//
//     setState(() {
//       _isPosting = true;
//     });
//
//     try {
//       //'📝 CREATE POST: Starting post creation...');
//       //'📝 CREATE POST: Title: "$title"');
//       //'📝 CREATE POST: Content: "$content"');
//       //'📝 CREATE POST: Visibility (UI): "$_visibility"');
//       //'📝 CREATE POST: Uploaded Image URL: ${_uploadedImageUrl ?? 'None'}');
//
//       String visibilityFormatted;
//       switch (_visibility) {
//         case 'Public':
//           visibilityFormatted = 'public';
//           break;
//         case 'Friends Only':
//           visibilityFormatted = 'friends';
//           break;
//         case 'Private':
//           visibilityFormatted = 'private';
//           break;
//         default:
//           visibilityFormatted = 'public';
//       }
//
//       //'📝 CREATE POST: Visibility (API): "$visibilityFormatted"');
//
//       final response = await SocialApiService.createPost(
//         content,
//         visibilityFormatted,
//         title: title.isNotEmpty ? title : null,
//         imageUrl: _uploadedImageUrl,
//       );
//
//       //'📝 CREATE POST: Response status: ${response['status']}');
//       //'📝 CREATE POST: Response  $response');
//
//       if (response['status'] == 'success') {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Good news shared! 🌟'),
//               backgroundColor: ThemeTokens.primaryGreen,
//               duration: Duration(seconds: 2),
//             ),
//           );
//           Navigator.pop(context, true);
//         }
//       } else {
//         throw Exception(response['error'] ?? 'Failed to create post');
//       }
//     } catch (e) {
//       //'❌ CREATE POST: Error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to share post: $e'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isPosting = false;
//         });
//       }
//     }
//   }
//
//   void _selectImage() async {
//     var cameraStatus = await Permission.camera.status;
//     var galleryStatus = await Permission.photos.status;
//
//     if (!galleryStatus.isGranted && Platform.isAndroid) {
//       galleryStatus = await Permission.storage.status;
//     }
//
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: ThemeTokens.cardBackground,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) => Container(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//               'Add Photo',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Row(
//               children: [
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     onPressed: () {
//                       Navigator.pop(context);
//                       _pickImageFromCamera();
//                     },
//                     icon: const Icon(Icons.camera_alt, color: ThemeTokens.primaryGreen),
//                     label: const Text(
//                       'Camera',
//                       style: TextStyle(color: ThemeTokens.primaryGreen),
//                     ),
//                     style: OutlinedButton.styleFrom(
//                       side: const BorderSide(color: ThemeTokens.primaryGreen),
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     onPressed: () {
//                       Navigator.pop(context);
//                       _pickImageFromGallery();
//                     },
//                     icon: const Icon(Icons.photo_library, color: ThemeTokens.primaryGreen),
//                     label: const Text(
//                       'Gallery',
//                       style: TextStyle(color: ThemeTokens.primaryGreen),
//                     ),
//                     style: OutlinedButton.styleFrom(
//                       side: const BorderSide(color: ThemeTokens.primaryGreen),
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             const Text(
//               'Maximum file size: 5MB',
//               style: TextStyle(
//                 color: ThemeTokens.textSecondary,
//                 fontSize: 12,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _pickImageFromCamera() async {
//     try {
//       final cameraPermission = await Permission.camera.request();
//
//       if (cameraPermission.isGranted) {
//         final XFile? image = await _picker.pickImage(
//           source: ImageSource.camera,
//           maxWidth: 1920,
//           maxHeight: 1080,
//           imageQuality: 85,
//         );
//
//         if (image != null) {
//           await _handleImageSelection(File(image.path));
//         }
//       } else if (cameraPermission.isPermanentlyDenied) {
//         _showPermissionDeniedDialog('Camera');
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Camera permission is required to take photos'),
//               backgroundColor: Colors.orange,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       //'📷 Camera error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('📷 Camera error: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   Future<void> _pickImageFromGallery() async {
//     try {
//       PermissionStatus galleryPermission = await Permission.photos.request();
//
//       if (galleryPermission.isDenied && Platform.isAndroid) {
//         galleryPermission = await Permission.storage.request();
//       }
//
//       //'📂 Gallery permission status: $galleryPermission');
//
//       if (galleryPermission.isGranted ||
//           galleryPermission.isLimited ||
//           galleryPermission.isPermanentlyDenied) {
//
//         final XFile? image = await _picker.pickImage(
//           source: ImageSource.gallery,
//           maxWidth: 1920,
//           maxHeight: 1080,
//           imageQuality: 85,
//         );
//
//         if (image != null) {
//           await _handleImageSelection(File(image.path));
//         }
//       } else {
//         _showPermissionDeniedDialog('Gallery');
//       }
//     } catch (e) {
//       //'📂 Gallery error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('📂 Gallery error: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   Future<void> _handleImageSelection(File imageFile) async {
//     try {
//       //'📸 IMAGE HANDLING: Starting...');
//       //'📸 IMAGE HANDLING: File path: ${imageFile.path}');
//
//       if (!await imageFile.exists()) {
//         //'❌ IMAGE HANDLING: File does not exist!');
//         _showError('Image file not found');
//         return;
//       }
//       //'✅ IMAGE HANDLING: File exists');
//
//       final fileSizeInBytes = await imageFile.length();
//       final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
//       //'📦 IMAGE HANDLING: File size: ${fileSizeInMB.toStringAsFixed(2)} MB');
//
//       if (fileSizeInMB > 5) {
//         _showError('Image size must be less than 5MB (Current: ${fileSizeInMB.toStringAsFixed(2)}MB)');
//         return;
//       }
//
//       setState(() {
//         _selectedImageFile = imageFile;
//         _isUploadingImage = true;
//         _uploadError = null;
//       });
//
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Row(
//               children: [
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Text('Uploading image...'),
//               ],
//             ),
//             duration: Duration(seconds: 30),
//             backgroundColor: ThemeTokens.primaryGreen,
//           ),
//         );
//       }
//
//       //'📤 IMAGE HANDLING: Calling upload API...');
//       final uploadResponse = await SocialApiService.uploadPostImage(imageFile);
//
//       //'📤 IMAGE HANDLING: Upload response: $uploadResponse');
//       //'📤 IMAGE HANDLING: Response status: ${uploadResponse['status']}');
//
//       if (uploadResponse['status'] == 'success') {
//         final imageUrl = uploadResponse['image_url'];
//
//         if (imageUrl == null || imageUrl.toString().isEmpty) {
//           throw Exception('No image URL returned from server');
//         }
//
//         setState(() {
//           _uploadedImageUrl = imageUrl;
//           _isUploadingImage = false;
//           _uploadError = null;
//         });
//
//         if (mounted) {
//           ScaffoldMessenger.of(context).hideCurrentSnackBar();
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('✅ Image uploaded successfully!'),
//               backgroundColor: ThemeTokens.primaryGreen,
//               duration: Duration(seconds: 2),
//             ),
//           );
//         }
//
//         //'✅ IMAGE HANDLING: Upload successful! URL: $_uploadedImageUrl');
//       } else {
//         final errorMsg = uploadResponse['error'] ?? 'Unknown upload error';
//         throw Exception(errorMsg);
//       }
//     } catch (e) {
//       //'❌ IMAGE HANDLING: Error: $e');
//       //'❌ IMAGE HANDLING: Error type: ${e.runtimeType}');
//
//       setState(() {
//         _selectedImageFile = null;
//         _uploadedImageUrl = null;
//         _isUploadingImage = false;
//         _uploadError = e.toString();
//       });
//
//       _showError('Upload failed: $e');
//     }
//   }
//
//   void _showError(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).hideCurrentSnackBar();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('❌ $message'),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 4),
//         ),
//       );
//     }
//   }
//
//   void _showPermissionDeniedDialog(String permission) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('$permission Permission Required'),
//         content: Text('Please grant $permission access in Settings to select photos.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               openAppSettings();
//             },
//             child: const Text('Open Settings'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _removeImage() {
//     setState(() {
//       _selectedImageFile = null;
//       _uploadedImageUrl = null;
//       _uploadError = null;
//     });
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('🗑️ Image removed'),
//         backgroundColor: Colors.grey,
//         duration: Duration(seconds: 1),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//     final textTheme = theme.textTheme;
//     final primaryColor = colorScheme.primary;
//
//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         leading: IconButton(
//           icon: const Icon(Icons.close),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Padding(
//           padding: const EdgeInsets.all(3.0),
//           child: const Text('Create Post'),
//         ),
//         centerTitle: false,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ✅ FINAL LAYOUT: ME (left) + You/Public ▼ (middle) + POST BUTTON (right)
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 // ✅ "ME" AVATAR - Gradient + Shadow सह
//                 Container(
//                   width: 60,
//                   height: 60,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: LinearGradient(
//                       colors: [
//                         primaryColor.withOpacity(0.9),
//                         primaryColor.withOpacity(0.6),
//                       ],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: primaryColor.withOpacity(0.4),
//                         blurRadius: 12,
//                         offset: const Offset(0, 4),
//                       ),
//                     ],
//                   ),
//                   child: Center(
//                     child: Text(
//                       'me',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w900,
//                         fontSize: 20,
//                         letterSpacing: 1.0,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 // ✅ "YOU" + VISIBILITY DROPDOWN (WITH ▼ ARROW)
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       // ✅ "You" लहान फॉन्टमध्ये (14)
//                       Text(
//                         'You',
//                         style: textTheme.titleLarge?.copyWith(
//                           color: colorScheme.onSurface,
//                           fontSize: 14,
//                           fontWeight: FontWeight.w700,
//                           letterSpacing: 0.3,
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//                       // ✅ VISIBILITY - WITH ▼ ARROW (DEFAULT DROPDOWN)
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//                         decoration: BoxDecoration(
//                           color: colorScheme.surfaceVariant.withOpacity(0.7),
//                           borderRadius: BorderRadius.circular(24),
//                           border: Border.all(
//                             color: primaryColor.withOpacity(0.4),
//                             width: 1.5,
//                           ),
//                         ),
//                         child: DropdownButton<String>(
//                           value: _visibility,
//                           dropdownColor: theme.cardTheme.color ?? colorScheme.surface,
//                           underline: Container(),
//                           isDense: true,
//                           iconEnabledColor: primaryColor,
//                           style: TextStyle(
//                             color: colorScheme.onSurface,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w700,
//                           ),
//                           items: ['Public', 'Friends Only', 'Private'].map((String value) {
//                             IconData icon;
//                             switch (value) {
//                               case 'Public':
//                                 icon = Icons.public;
//                                 break;
//                               case 'Friends Only':
//                                 icon = Icons.people;
//                                 break;
//                               case 'Private':
//                                 icon = Icons.lock;
//                                 break;
//                               default:
//                                 icon = Icons.public;
//                             }
//
//                             return DropdownMenuItem<String>(
//                               value: value,
//                               child: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Icon(
//                                     icon,
//                                     size: 18,
//                                     color: primaryColor,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Text(
//                                     value,
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w700,
//                                       color: colorScheme.onSurface,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           }).toList(),
//                           onChanged: (String? newValue) {
//                             setState(() {
//                               _visibility = newValue!;
//                             });
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 // ✅ POST BUTTON - ONLY "Post" TEXT
//                 Container(
//                   decoration: BoxDecoration(
//                     gradient: _canPost
//                         ? LinearGradient(
//                       colors: [
//                         primaryColor,
//                         primaryColor.withOpacity(0.8),
//                       ],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     )
//                         : null,
//                     color: _canPost ? null : primaryColor.withOpacity(0.3),
//                     borderRadius: BorderRadius.circular(28),
//                     boxShadow: _canPost
//                         ? [
//                       BoxShadow(
//                         color: primaryColor.withOpacity(0.5),
//                         blurRadius: 15,
//                         offset: const Offset(0, 5),
//                       ),
//                     ]
//                         : null,
//                   ),
//                   child: Material(
//                     color: Colors.transparent,
//                     child: InkWell(
//                       onTap: _canPost ? _createPost : null,
//                       borderRadius: BorderRadius.circular(28),
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
//                         child: Text(
//                           'Post',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 16,
//                             fontWeight: FontWeight.w700,
//                             letterSpacing: 0.5,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 28),
//
//             // ✅ TEXT INPUT (PROFESSIONAL CARD WITH GRADIENT BORDER)
//             Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     primaryColor.withOpacity(0.3),
//                     primaryColor.withOpacity(0.1),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               padding: const EdgeInsets.all(2),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: theme.cardTheme.color ?? colorScheme.surface,
//                   borderRadius: BorderRadius.circular(18),
//                 ),
//                 padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
//                 child: TextField(
//                   controller: _textController,
//                   maxLines: 8,
//                   minLines: 8,
//                   style: textTheme.bodyLarge?.copyWith(
//                     color: colorScheme.onSurface,
//                     height: 1.6,
//                     fontSize: 16,
//                   ),
//                   decoration: InputDecoration(
//                     hintText: 'Share something positive that happened today... (Required)',
//                     hintStyle: textTheme.bodyLarge?.copyWith(
//                       color: colorScheme.onSurfaceVariant.withOpacity(0.6),
//                       fontSize: 16,
//                     ),
//                     border: InputBorder.none,
//                     contentPadding: EdgeInsets.zero,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//
//             // ✅ UPLOAD ERROR MESSAGE
//             if (_uploadError != null)
//               Container(
//                 padding: const EdgeInsets.all(14),
//                 margin: const EdgeInsets.only(bottom: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.red.withOpacity(0.08),
//                   border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
//                   borderRadius: BorderRadius.circular(14),
//                 ),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.error_outline, color: Colors.red, size: 20),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Text(
//                         _uploadError!,
//                         style: textTheme.bodyMedium?.copyWith(
//                           color: Colors.red,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//             // ✅ IMAGE PREVIEW
//             if (_selectedImageFile != null)
//               Container(
//                 margin: const EdgeInsets.only(bottom: 20),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(18),
//                   boxShadow: [
//                     BoxShadow(
//                       color: primaryColor.withOpacity(0.15),
//                       blurRadius: 20,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Card(
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
//                   elevation: 0,
//                   child: Stack(
//                     children: [
//                       Column(
//                         children: [
//                           ClipRRect(
//                             borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//                             child: Image.file(
//                               _selectedImageFile!,
//                               height: 240,
//                               width: double.infinity,
//                               fit: BoxFit.cover,
//                               filterQuality: FilterQuality.high,
//                             ),
//                           ),
//                           Container(
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               color: colorScheme.surfaceVariant.withOpacity(0.3),
//                               borderRadius: const BorderRadius.vertical(
//                                 bottom: Radius.circular(16),
//                               ),
//                             ),
//                             child: Row(
//                               children: [
//                                 Icon(
//                                   _isUploadingImage ? Icons.cloud_upload : Icons.check_circle,
//                                   color: _isUploadingImage ? primaryColor : Colors.green,
//                                   size: 22,
//                                 ),
//                                 const SizedBox(width: 12),
//                                 Expanded(
//                                   child: Text(
//                                     _isUploadingImage
//                                         ? 'Uploading image...'
//                                         : 'Image ready to share',
//                                     style: textTheme.bodyMedium?.copyWith(
//                                       color: colorScheme.onSurface,
//                                       fontSize: 15,
//                                       fontWeight: FontWeight.w700,
//                                     ),
//                                   ),
//                                 ),
//                                 if (!_isUploadingImage)
//                                   IconButton(
//                                     onPressed: _removeImage,
//                                     icon: const Icon(
//                                       Icons.close_rounded,
//                                       color: Colors.red,
//                                       size: 24,
//                                     ),
//                                     tooltip: 'Remove image',
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                       if (_isUploadingImage)
//                         Positioned.fill(
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.black.withOpacity(0.3),
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                             child: const Center(
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 3,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//
//             // ✅ ADD PHOTO BUTTON (GRADIENT STYLE)
//             Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     primaryColor.withOpacity(0.15),
//                     primaryColor.withOpacity(0.05),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(18),
//                 border: Border.all(
//                   color: _isUploadingImage ? Colors.grey : primaryColor.withOpacity(0.4),
//                   width: 2,
//                 ),
//               ),
//               child: Material(
//                 color: Colors.transparent,
//                 child: InkWell(
//                   onTap: _isUploadingImage ? null : _selectImage,
//                   borderRadius: BorderRadius.circular(16),
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 18),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.add_a_photo_outlined,
//                           color: _isUploadingImage ? Colors.grey : primaryColor,
//                           size: 24,
//                         ),
//                         const SizedBox(width: 12),
//                         Text(
//                           _selectedImageFile == null ? 'Add Photo (Optional)' : 'Change Photo',
//                           style: textTheme.labelLarge?.copyWith(
//                             color: _isUploadingImage ? Colors.grey : primaryColor,
//                             fontSize: 16,
//                             fontWeight: FontWeight.w800,
//                             letterSpacing: 0.3,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 30),
//           ],
//         ),
//       ),
//     );
//   }
// }