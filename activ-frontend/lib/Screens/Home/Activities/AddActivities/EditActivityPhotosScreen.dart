import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../api_calling/activity_photo_upload.dart';
import '../../../../api_calling/activity_setup_api.dart';
import '../../../../api_calling/api_constant.dart';
import '../../../../api_calling/api_request.dart';
import '../../../onboarding_widgets.dart';

/// Editing an existing activity must never create another activity or restart
/// the onboarding wizard. Every exit returns the current server-saved selection.
class EditActivityPhotosScreen extends StatefulWidget {
  const EditActivityPhotosScreen(
      {super.key,
      required this.activityId,
      required this.activityName,
      required this.imageUrls,
      this.client});
  final String activityId, activityName;
  final List<String> imageUrls;
  final http.Client? client;

  @override
  State<EditActivityPhotosScreen> createState() =>
      _EditActivityPhotosScreenState();
}

class _EditActivityPhotosScreenState extends State<EditActivityPhotosScreen> {
  late final http.Client _client;
  late final ActivitySetupApi _api;
  late List<String> _urls;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urls = List.of(widget.imageUrls);
    _client = widget.client ?? http.Client();
    _api = ActivitySetupApi(client: _client);
  }

  @override
  void dispose() {
    _api.dispose();
    if (widget.client == null) _client.close();
    super.dispose();
  }

  void _back() {
    if (!_busy) Navigator.pop(context, List<String>.of(_urls));
  }

  Future<void> _add() async {
    if (_busy) return;
    if (_urls.length >= 12) {
      setState(() => _error = 'You can upload a maximum of 12 photos.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await SharedPreference.readStr('jwt_token');
      if (token == null || token.isEmpty) {
        throw const ActivitySetupException(
            'Your session has expired. Please sign in again.');
      }
      final photos = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (!mounted || photos.isEmpty) return;
      if (_urls.length + photos.length > 12) {
        throw ActivityUploadException(
            'You can add ${12 - _urls.length} more photos.');
      }
      for (final photo in photos) {
        final bytes = await photo.readAsBytes();
        if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
          throw const ActivityUploadException(
              'Each photo must be non-empty and under 5 MB.');
        }
      }
      final urls =
          await ActivityPhotoUploader(client: _client, baseUrl: BASE_URL)
              .uploadImages(
        token: token,
        serviceId: widget.activityId,
        images: photos,
        replaceImages: false,
      );
      if (mounted) setState(() => _urls = urls);
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error is ActivityUploadException || error is ActivitySetupException
                ? error.toString()
                : 'Unable to upload photos. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String url) async {
    if (_busy) return;
    if (_urls.length <= 4) {
      setState(() => _error =
          'Keep at least 4 photos. Add a replacement before removing this photo.');
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Remove photo?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Remove')),
              ],
            ));
    if (!mounted || confirmed != true || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final urls = await _api.removePhoto(widget.activityId, url);
      if (mounted) setState(() => _urls = urls);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<List<String>>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: OnboardingScaffold(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 8),
              child: Row(children: [
                IconButton(
                    tooltip: 'Back to activity review',
                    onPressed: _busy ? null : _back,
                    icon: const Icon(Icons.arrow_back)),
                const Expanded(
                    child:
                        Text('Edit Photos', style: OnboardingStyles.heading)),
              ])),
          Expanded(
              child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(widget.activityName,
                style: OnboardingStyles.heading.copyWith(fontSize: 22)),
            const SizedBox(height: 8),
            Text('${_urls.length} / 12 photos'),
            const SizedBox(height: 8),
            const Text(
                'Add or remove photos here. Changes are saved as you make them.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
                key: const Key('add-activity-photos'),
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Photos')),
            if (_busy)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red))),
            for (var index = 0; index < _urls.length; index++)
              Padding(
                key: ValueKey(_urls[index]),
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                              aspectRatio: 1.95,
                              child: Image.network(_urls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.image_outlined,
                                          size: 48))))),
                      Row(children: [
                        Expanded(
                            child: Text(index == 0
                                ? 'Cover photo'
                                : 'Photo ${index + 1}')),
                        TextButton.icon(
                            key: Key('remove-activity-photo-$index'),
                            onPressed:
                                _busy ? null : () => _remove(_urls[index]),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove')),
                      ]),
                    ]),
              ),
          ])),
          Padding(
              padding: const EdgeInsets.all(20),
              child: OnboardingButton(
                  label: 'Save Changes', onPressed: _busy ? null : _back)),
        ])),
      );
}
