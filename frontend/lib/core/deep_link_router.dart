import 'package:flutter/material.dart';
import 'package:cricket_scorer/features/dashboard/screens/my_teams_screen.dart';

class DeepLinkRouter {
  /// Parses and navigates incoming deep-links / universal links.
  /// Example supported links:
  /// - https://cricup.app/team/TC-8A93F2 (Direct Team invite)
  static bool handleLink(BuildContext context, String url) {
    try {
      final uri = Uri.parse(url.trim());
      
      // Check path segment for team invite routing: /team/TC-XXXXXX
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'team') {
        if (uri.pathSegments.length >= 2) {
          final code = uri.pathSegments[1];
          if (code.startsWith('TC-')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyTeamsScreen(
                  joinTeamCode: code,
                  initialTabIndex: 0,
                ),
              ),
            );
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint("[DeepLinkRouter Error] Failed to parse link '$url': $e");
    }
    return false;
  }
}
