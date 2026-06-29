import 'package:flutter/material.dart';
import 'package:cricket_scorer/core/theme.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final dynamic error;
  final String? customMessage;
  final VoidCallback? onRetry;

  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.customMessage,
    this.onRetry,
  });

  String _getFriendlyMessage(dynamic err) {
    if (customMessage != null) return customMessage!;
    if (err == null) return "An unexpected error occurred. Please try again.";
    
    final errStr = err.toString();
    if (errStr.contains("Connection timeout") || 
        errStr.contains("check your internet connection") ||
        errStr.contains("SocketException")) {
      return "Connection timeout. Please check your internet connection and try again.";
    }
    if (errStr.contains("404") || errStr.contains("no longer available")) {
      return "This item is no longer available.";
    }
    if (errStr.contains("403") || errStr.contains("permission")) {
      return "You don't have permission to perform this action.";
    }
    if (errStr.contains("422") || errStr.contains("check the information")) {
      return "Please check the information and try again.";
    }
    if (errStr.contains("500") || errStr.contains("Something went wrong")) {
      return "Something went wrong. Please try again.";
    }
    
    return errStr;
  }

  IconData _getErrorIcon(String message) {
    if (message.contains("Connection timeout")) {
      return Icons.wifi_off_rounded;
    }
    if (message.contains("permission")) {
      return Icons.lock_outline_rounded;
    }
    if (message.contains("no longer available")) {
      return Icons.find_in_page_outlined;
    }
    return Icons.error_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final message = _getFriendlyMessage(error);
    final icon = _getErrorIcon(message);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 70,
              color: AppColors.error,
            ),
            const SizedBox(height: 20),
            Text(
              "Error Occurred",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
