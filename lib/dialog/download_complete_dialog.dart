import 'package:flutter/material.dart';

class DownloadCompleteDialog extends StatefulWidget {
  final String fileName;
  final String filePath;
  final VoidCallback onArchive;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const DownloadCompleteDialog({
    required this.fileName,
    required this.filePath,
    required this.onArchive,
    required this.onView,
    required this.onDelete,
    super.key,
  });

  @override
  State<DownloadCompleteDialog> createState() => _DownloadCompleteDialogState();
}

class _DownloadCompleteDialogState extends State<DownloadCompleteDialog> {
  bool _isArchiving = false;
  bool _isViewing = false;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: const Text('Download Complete!'),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'File Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Name: ${widget.fileName}',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: ✅ Encrypted & Secured',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'What would you like to do?',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      actions: [
        // View button
        TextButton.icon(
          onPressed: _isViewing
              ? null
              : () async {
                  setState(() => _isViewing = true);
                  try {
                    widget.onView();
                    Navigator.of(context).pop();
                  } catch (e) {
                    print('Error viewing file: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                  if (mounted) setState(() => _isViewing = false);
                },
          icon: _isViewing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.preview),
          label: const Text('View'),
        ),

        // Archive button
        FilledButton.icon(
          onPressed: _isArchiving
              ? null
              : () async {
                  setState(() => _isArchiving = true);
                  try {
                    widget.onArchive();
                    Navigator.of(context).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '✅ File moved to Archived',
                                ),
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 3),
                          backgroundColor: Colors.green[50],
                        ),
                      );
                    }
                  } catch (e) {
                    print('Error archiving file: $e');
                    if (mounted) {
                      setState(() => _isArchiving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green[700],
          ),
          icon: _isArchiving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.archive),
          label: const Text('Archive'),
        ),

        // Delete button
        TextButton.icon(
          onPressed: _isDeleting
              ? null
              : () async {
                  setState(() => _isDeleting = true);
                  try {
                    widget.onDelete();
                    Navigator.of(context).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('File deleted'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    print('Error deleting file: $e');
                    if (mounted) {
                      setState(() => _isDeleting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red[700],
          ),
          icon: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete),
          label: const Text('Delete'),
        ),
      ],
    );
  }
}
