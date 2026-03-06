import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late Map<int, bool> expandedSections;

  @override
  void initState() {
    super.initState();
    expandedSections = {
      for (int i = 0; i < 9; i++) i: false,
    };
  }

  final List<Map<String, dynamic>> sections = [
    {
      'id': 0,
      'title': 'Information We Collect',
      'icon': '📋',
      'subsections': [
        {
          'title': 'Personal Information',
          'items': [
            'Name / Display Name',
            'Email Address',
            'Phone Number (optional)',
            'Password (securely encrypted & never shared)',
          ]
        },
        {
          'title': 'Automatically Collected Data',
          'items': [
            'App usage data & reading history',
            'Device information',
            'Crash reports',
            'Video watch history & duration',
            'Analytics for improving user experience',
          ]
        },
        {
          'title': 'Third-Party Data',
          'items': [
            'RSS News API content',
            'AI-generated rewritten news (via GPT / AI API)',
            'YouTube video metadata (title, thumbnail, video ID)',
          ]
        }
      ]
    },
    {
      'id': 1,
      'title': 'How We Use Your Information',
      'icon': '🎯',
      'items': [
        'Creating and managing your account',
        'Showing personalized news categories based on your preferences',
        'Personalizing your video feed (TikTok-style)',
        'Tracking video watch history to improve recommendations',
        'Improving app features and overall experience',
        'Rewriting negative news into positive content using AI',
        'Sending notifications about new posts or updates',
        'Ensuring app security and preventing misuse',
      ]
    },
    {
      'id': 2,
      'title': 'Login & Authentication',
      'icon': '🔐',
      'subsections': [
        {
          'title': 'Email & Password Login',
          'items': [
            'Standard email + password authentication',
            'Passwords are encrypted and never stored in plain text',
            'JWT tokens used for secure session management',
          ]
        },

      ]
    },
    {
      'id': 3,
      'title': 'Video Feed & YouTube Data',
      'icon': '🎬',
      'items': [
        'JoyScroll displays YouTube videos in a personalized feed',
        'Videos are AI-filtered for positive, uplifting content',
        'We store YouTube video IDs, titles, and thumbnails on our servers',
        'We track which videos you watch to personalize your feed',
        'Watch duration and completion status may be recorded',
        'We do not store actual video files — videos are streamed from YouTube',
        'YouTube\'s own Terms of Service and Privacy Policy apply to video content',
        'You can save videos to your favorites within the app',
      ]
    },
    {
      'id': 4,
      'title': 'How We Store and Protect Data',
      'icon': '🛡️',
      'subsections': [
        {
          'title': 'Security Measures',
          'items': [
            'Secure encrypted connections (HTTPS/TLS)',
            'Secure password hashing (bcrypt)',
            'JWT token-based authentication',
            'Limited access to sensitive data',
            'Strict server-side validations',
          ]
        },
        {
          'title': 'Data Policy',
          'items': [
            'We never sell, rent, or exchange your personal data',
            'Data is stored on secure servers',
            'We retain data only as long as your account is active',
          ]
        }
      ]
    },
    {
      'id': 5,
      'title': 'Third-Party Services',
      'icon': '🔗',
      'items': [
        'YouTube Data API → for video content in the feed',
        'AI API (GPT / our AI system) → used to rewrite negative news',
        'RSS News APIs → used to fetch news articles',
        'Firebase / Push Notification service → for app notifications',
        'Database service → for storing user data securely',
        'All third-party services follow their own privacy policies',
      ]
    },
    {
      'id': 8,
      'title': 'Your Rights & Choices',
      'icon': '⚖️',
      'items': [
        'Access: You can view your profile and data anytime',
        'Edit: You can update your display name and phone number',
        'Delete: You can request full account and data deletion',
        'Preferences: You can update your news category preferences anytime',
        'Notifications: You can disable push notifications from device settings',
      ]
    },
    {
      'id': 9,
      'title': "Children's Privacy",
      'icon': '👶',
      'items': [
        'JoyScroll is not intended for children under 13 years of age',
        'We do not knowingly collect data from children under 13',
        'If such data is detected, it will be removed immediately',
        'Parents or guardians may contact us to request data removal',
      ]
    },
    {
      'id': 10,
      'title': 'Data Deletion Request',
      'icon': '🗑️',
      'items': [
        'Request account or data deletion anytime',
        'Email: support@joyscroll.com',
        'Data deletion completed within 7–15 working days',
        'After deletion, all personal data, posts, and history will be permanently removed',
      ]
    }
  ];

  void _toggleSection(int id) {
    setState(() {
      expandedSections[id] = !expandedSections[id]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Last Updated Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Text(
                  '📅 Last Updated: February 2026  •  Version 1.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Intro Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: primaryColor, width: 4),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'JoyScroll ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        TextSpan(
                          text:
                          'is committed to protecting your privacy. This Privacy Policy explains how we collect, use, store, and protect your information when you use our mobile application — including our News Feed and Video Feed.',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sections
              ...sections.asMap().entries.map((entry) {
                int id = entry.key;
                Map<String, dynamic> section = entry.value;
                bool isExpanded = expandedSections[id] ?? false;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isDark ? Colors.grey[850] : Colors.white,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Text(
                            section['icon'],
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(
                            section['title'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          trailing: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: primaryColor,
                          ),
                          onTap: () => _toggleSection(id),
                        ),
                        if (isExpanded) ...[
                          Divider(
                            height: 1,
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: section.containsKey('subsections')
                                ? _buildSubsections(
                              section['subsections'],
                              isDark,
                            )
                                : _buildItems(section['items'], isDark),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),

              // Contact Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? Colors.grey[850] : Colors.white,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: primaryColor, width: 4),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mail, color: primaryColor, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Contact Us',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'If you have any questions about this Privacy Policy or data deletion requests:',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.8)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('📧 support@joyscroll.com'),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: const Text(
                                '📧 support@joyscroll.com',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Footer Note
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? Colors.grey[850]
                      : primaryColor.withOpacity(0.1),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Text(
                  'We may update this policy occasionally. We will notify users of significant changes by updating the "Last Updated" date and, where required, sending an in-app notification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItems(List<dynamic> items, bool isDark) {
    return Column(
      children: items
          .map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 4),
              child: Icon(
                Icons.check_circle,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Expanded(
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ))
          .toList(),
    );
  }

  Widget _buildSubsections(
      List<dynamic> subsections,
      bool isDark,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subsections
          .map((subsection) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔹 ${subsection['title']}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: (subsection['items'] as List<dynamic>)
                  .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 12,
                        top: 4,
                      ),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
                  .toList(),
            ),
          ],
        ),
      ))
          .toList(),
    );
  }
}