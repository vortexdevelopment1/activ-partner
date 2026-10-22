import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../Style/app_colors.dart';
import '../../Utills/venue_postal_code.dart';
import '../../api_calling/api_constant.dart';
import '../../api_calling/api_request.dart';
import '../onboarding_widgets.dart';

const _accent = Color(0xFFA634FF);

class VenueInfoScreen extends StatefulWidget {
  const VenueInfoScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<VenueInfoScreen> createState() => _VenueInfoScreenState();
}

class _VenueInfoScreenState extends State<VenueInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _controllers = {
    for (final field in [
      'name',
      'description',
      'address',
      'locationUrl',
      'flatBuilding',
      'venuePhone',
      'city',
      'state',
      'zipCode'
    ])
      field: TextEditingController(),
  };
  Map<String, dynamic> _venue = {};
  Map<String, dynamic>? _request;
  String? _loadError, _submissionError;
  bool _loading = true, _submitting = false, _canEdit = true;
  final List<Map<String, String>> _placeSuggestions = [];
  Timer? _addressSearchDebounce;
  bool _showPlaceSuggestions = false;
  double? _selectedLatitude, _selectedLongitude;
  bool get _pending =>
      _request?['status']?.toString().toLowerCase() == 'pending';
  bool get _locked => _pending || !_canEdit;
  bool get _changed => _controllers.entries
      .any((entry) => entry.value.text.trim() != _initialValue(entry.key));

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers.values) {
      controller.addListener(_onChange);
    }
    _loadVenue();
  }

  void _onChange() {
    if (mounted) setState(() => _submissionError = null);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _addressSearchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _firstVenueValue(List<String> keys) {
    for (final key in keys) {
      final value = _venue[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  String _initialValue(String key) {
    switch (key) {
      case 'name':
        return _firstVenueValue(['name', 'venue_name']);
      case 'description':
        return _firstVenueValue(['description', 'venue_description']);
      case 'address':
        final address = _firstVenueValue([
          'address', 'venue_address', 'venueAddress', 'address_line_1',
          'venue_search_address'
        ]);
        if (address.trim().isNotEmpty) return address;
        return ['flatBuilding', 'city', 'state', 'zipCode']
            .map(_initialValue)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .join(', ');
      case 'locationUrl':
        return _firstVenueValue(
            ['locationUrl', 'location_url', 'venue_location_url']);
      case 'flatBuilding':
        return _firstVenueValue(
            ['flatBuilding', 'address_line_2', 'venue_area']);
      case 'venuePhone':
        return _firstVenueValue(
            ['venuePhone', 'phone', 'venue_phone', 'contact_phone_e164']);
      case 'city':
        return _firstVenueValue(['city', 'venue_city']);
      case 'state':
        return _firstVenueValue(['state', 'venue_state']);
      case 'zipCode':
        return _firstVenueValue(['zipCode', 'postal_code', 'venue_pin_code']);
      default:
        return _firstVenueValue([key]);
    }
  }

  Map<String, dynamic> _body(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Invalid response');
    return Map<String, dynamic>.from(decoded);
  }

  List<Map<String, dynamic>> _venuesFromData(dynamic data) {
    final dynamic source = data is List
        ? data
        : data is Map
            ? data['items'] ?? data['venues'] ?? data['data']
            : null;
    if (source is! List) {
      throw const FormatException(
          'Could not load venue details. Please try again.');
    }
    return source
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _idOf(Map<String, dynamic> item) =>
      (item['id'] ?? item['_id'] ?? '').toString();

  Future<void> _loadVenue() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final userType = await SharedPreference.readStr('user_type') ?? '';
      final selectedId = await SharedPreference.readStr('venue_id');
      if (!mounted) return;
      _canEdit = userType != 'team_member';
      if (token.isEmpty) {
        throw const FormatException(
            'Your session has expired. Please log in again.');
      }
      final headers = {'accept': '*/*', 'Authorization': 'Bearer $token'};
      final response = await (widget.client?.get ??
          http.get)(Uri.parse(MY_APPROVED_VENUES_URL), headers: headers);
      if (!mounted) return;
      if (response.statusCode == 401) {
        throw const FormatException(
            'Your session has expired. Please log in again.');
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw const FormatException(
            'Could not load venue details. Please try again.');
      }
      final venues = _venuesFromData(_body(response.body)['data']);
      final matching =
          venues.where((venue) => _idOf(venue) == selectedId?.toString());
      _venue = venues.isEmpty
          ? {}
          : matching.isNotEmpty
              ? matching.first
              : venues.first;
      _request = null;
      if (_canEdit && _venue.isNotEmpty) {
        final requestsResponse = await (widget.client?.get ?? http.get)(
            Uri.parse('$CREATE_VENUE_URL/update-requests/my'),
            headers: headers);
        if (!mounted) return;
        if (requestsResponse.statusCode != 200 &&
            requestsResponse.statusCode != 201) {
          throw const FormatException(
              'Could not load the review status. Please try again.');
        }
        final requestsData = _body(requestsResponse.body)['data'];
        if (requestsData is! List) {
          throw const FormatException(
              'Could not load the review status. Please try again.');
        }
        final requests = requestsData
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) =>
                (e['venueId'] ?? e['venue_id'] ?? '').toString() ==
                _idOf(_venue))
            .toList();
        final pending = requests
            .where((e) => e['status']?.toString().toLowerCase() == 'pending');
        if (pending.isNotEmpty) {
          _request = pending.first;
        } else if (requests.isNotEmpty &&
            requests.first['status']?.toString().toLowerCase() == 'rejected') {
          _request = requests.first;
        }
      }
      if (!mounted) return;
      final changes = _request?['requestedChanges'] is Map
          ? Map<String, dynamic>.from(_request!['requestedChanges'])
          : _request ?? {};
      for (final entry in _controllers.entries) {
        entry.value.text =
            changes[entry.key]?.toString() ?? _initialValue(entry.key);
      }
    } on FormatException catch (error) {
      if (mounted) _loadError = error.message;
    } catch (_) {
      if (mounted) _loadError = 'Network error. Please check your connection.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || _locked || !_formKey.currentState!.validate()) return;
    if (!_changed) {
      setState(() =>
          _submissionError = 'Make a change before submitting for review.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _submissionError = null;
    });
    try {
      final payload = <String, dynamic>{};
      for (final entry in _controllers.entries) {
        final value = entry.value.text.trim();
        if (entry.key == 'locationUrl' && value.isEmpty) continue;
        payload[entry.key] = value;
      }
      if (_selectedLatitude != null) payload['latitude'] = _selectedLatitude;
      if (_selectedLongitude != null) payload['longitude'] = _selectedLongitude;
      final token = await SharedPreference.readStr('jwt_token') ?? '';
      final response = await (widget.client?.post ?? http.post)(
        Uri.parse('$CREATE_VENUE_URL/${_venue['id']}/update-request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(payload),
      );
      if (!mounted) return;
      final body = _body(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['data'] is! Map) {
          throw const FormatException(
              'Could not confirm the review status. Please refresh.');
        }
        setState(() => _request = Map<String, dynamic>.from(body['data']));
        if (!_pending) await _loadVenue();
        if (!mounted) return;
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else if (response.statusCode == 409) {
        await _loadVenue();
        if (mounted) {
          setState(() => _submissionError = _pending
              ? null
              : 'A review request already exists. Please refresh.');
        }
      } else {
        final message = body['message'];
        setState(() => _submissionError = message is List
            ? message.join('\n')
            : message is String && response.statusCode < 500
                ? message
                : 'Could not submit changes. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submissionError =
            'Could not submit changes. Please check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validate(String key, String? value) {
    final text = value?.trim() ?? '';
    if (key != 'flatBuilding' && text.isEmpty) return 'This field is required.';
    if (key == 'description' && text.length > 200) {
      return 'Use no more than 200 characters.';
    }
    if (key == 'name' && text.length > 255) {
      return 'Use no more than 255 characters.';
    }
    if (key == 'zipCode' && !RegExp(r'^\d{6}$').hasMatch(text)) {
      return 'Enter a six-digit pin code.';
    }
    if (key == 'venuePhone' && !RegExp(r'^\+?[\d\s()-]+$').hasMatch(text)) {
      return 'Enter a valid phone number.';
    }
    if (key == 'venuePhone') {
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10 || digits.length > 15) {
        return 'Enter a valid phone number.';
      }
    }
    if (key == 'address') {
      final changedAddress = text != _initialValue('address');
      if (changedAddress && _controllers['locationUrl']!.text.trim().isEmpty) {
        return 'Select an address from the suggestions.';
      }
    }
    if (key == 'locationUrl') {
      if (text.isEmpty) return null;
      final uri = Uri.tryParse(text);
      final host = uri?.host.toLowerCase() ?? '';
      final isGoogleMaps = host == 'maps.app.goo.gl' ||
          host == 'maps.google.com' ||
          (host == 'goo.gl' && (uri?.path.startsWith('/maps') ?? false)) ||
          ((host == 'google.com' ||
                  host == 'www.google.com' ||
                  host == 'www.google.co.in') &&
              (uri?.path.startsWith('/maps') ?? false));
      if (uri?.scheme != 'https' || !isGoogleMaps) {
        return 'Enter a valid Google Maps link.';
      }
    }
    return null;
  }

  Future<void> _fetchPlaceSuggestions(String input) async {
    if (input.length < 2 || GOOGLE_MAPS_API_KEY.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _placeSuggestions.clear();
          _showPlaceSuggestions = false;
        });
      }
      return;
    }
    try {
      final response = await (widget.client?.post ?? http.post)(
        Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': GOOGLE_MAPS_API_KEY,
        },
        body: jsonEncode({
          'input': input,
          'includedRegionCodes': ['in'],
        }),
      );
      if (!mounted || response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      final suggestions = (data['suggestions'] as List? ?? [])
          .map<Map<String, String>>((suggestion) {
            final prediction = suggestion['placePrediction'] as Map?;
            return {
              'placeId': prediction?['placeId']?.toString() ?? '',
              'description':
                  (prediction?['text'] as Map?)?['text']?.toString() ?? '',
            };
          })
          .where((suggestion) =>
              suggestion['placeId']!.isNotEmpty &&
              suggestion['description']!.isNotEmpty)
          .take(5)
          .toList();
      setState(() {
        _placeSuggestions
          ..clear()
          ..addAll(suggestions);
        _showPlaceSuggestions = suggestions.isNotEmpty;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _placeSuggestions.clear();
          _showPlaceSuggestions = false;
        });
      }
    }
  }

  Future<void> _selectPlace(Map<String, String> suggestion) async {
    FocusScope.of(context).unfocus();
    final placeId = suggestion['placeId'] ?? '';
    setState(() {
      _controllers['address']!.text = suggestion['description'] ?? '';
      _controllers['locationUrl']!.text =
          'https://maps.google.com/?q=place_id:$placeId';
      _controllers['zipCode']!.clear();
      _showPlaceSuggestions = false;
      _placeSuggestions.clear();
      _submissionError = null;
    });
    if (placeId.isNotEmpty) await _fetchPlaceDetails(placeId);
  }

  Future<void> _fetchPlaceDetails(String placeId) async {
    if (GOOGLE_MAPS_API_KEY.trim().isEmpty) return;
    final selectedPlaceUrl = _controllers['locationUrl']!.text;
    try {
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
        headers: {
          'X-Goog-Api-Key': GOOGLE_MAPS_API_KEY,
          'X-Goog-FieldMask': 'addressComponents,location',
        },
      );
      if (!mounted || response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      final components = data['addressComponents'] as List? ?? [];
      String city = '', state = '', pincode = '';
      for (final component in components.whereType<Map>()) {
        final types =
            (component['types'] as List? ?? []).map((e) => e.toString());
        final longName = component['longText']?.toString() ?? '';
        if (types.contains('locality')) city = longName;
        if (types.contains('administrative_area_level_2') && city.isEmpty) {
          city = longName;
        }
        if (types.contains('administrative_area_level_1')) state = longName;
        if (types.contains('postal_code')) pincode = longName;
      }
      final location = data['location'] as Map?;
      final latitude = (location?['latitude'] as num?)?.toDouble();
      final longitude = (location?['longitude'] as num?)?.toDouble();
      if (!isValidVenuePostalCode(pincode) &&
          latitude != null &&
          longitude != null) {
        pincode = await resolveVenuePostalCode(
          latitude: latitude,
          longitude: longitude,
          apiKey: GOOGLE_MAPS_API_KEY,
          client: widget.client,
        );
      }
      if (!mounted || _controllers['locationUrl']!.text != selectedPlaceUrl) return;
      setState(() {
        if (city.isNotEmpty) _controllers['city']!.text = city;
        if (state.isNotEmpty) _controllers['state']!.text = state;
        _controllers['zipCode']!.text =
            isValidVenuePostalCode(pincode) ? pincode.trim() : '';
        _selectedLatitude = (location?['latitude'] as num?)?.toDouble();
        _selectedLongitude = (location?['longitude'] as num?)?.toDouble();
      });
    } catch (_) {}
  }

  Widget _addressField() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(
              TextSpan(text: 'Venue Address', children: [
                TextSpan(
                    text: '*',
                    style: TextStyle(
                        color: _locked
                            ? const Color(0xFFFFB6AF)
                            : AppColors.red)),
              ]),
              style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: _locked ? AppColors.hintColor : AppColors.darkBlack)),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('venue-update-address'),
            controller: _controllers['address'],
            enabled: !_locked && !_submitting,
            validator: (value) => _validate('address', value),
            style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 14,
                height: 1.4,
                color: _locked ? AppColors.hintColor : AppColors.darkBlack),
            keyboardType: TextInputType.streetAddress,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              _controllers['locationUrl']!.clear();
              _selectedLatitude = null;
              _selectedLongitude = null;
              _addressSearchDebounce?.cancel();
              _addressSearchDebounce =
                  Timer(const Duration(milliseconds: 450), () {
                _fetchPlaceSuggestions(value.trim());
              });
              if (mounted) setState(() => _submissionError = null);
            },
            decoration: OnboardingStyles.inputDecoration().copyWith(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              fillColor: _locked ? const Color(0x80FFFFFF) : Colors.white,
              suffixIcon: Icon(
                  _controllers['locationUrl']!.text.trim().isNotEmpty
                      ? Icons.check_circle
                      : Icons.search,
                  size: 24,
                  color: _controllers['locationUrl']!.text.trim().isNotEmpty
                      ? const Color(0xFF27AE60)
                      : AppColors.hintColor),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFDDE5CC))),
            ),
          ),
          if (_showPlaceSuggestions)
            Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD7DED1)),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 6,
                        offset: Offset(0, 2))
                  ]),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _placeSuggestions.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, thickness: 1, color: Color(0xFFE2E7DE)),
                itemBuilder: (context, index) {
                  final suggestion = _placeSuggestions[index];
                  return InkWell(
                    onTap: () => _selectPlace(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 22, color: AppColors.hintColor),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text(suggestion['description'] ?? '',
                                style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 15,
                                    height: 1.35,
                                    color: AppColors.darkBlack))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.help_outline, size: 14, color: AppColors.hintColor),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    'Copy & add your venue\u2019s location from Google Maps.',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: _locked
                            ? const Color(0xFFB3B8A2)
                            : AppColors.hintColor))),
          ]),
        ]),
      );

  Widget _field(String key, String label, {bool optional = false}) => Padding(
        padding: EdgeInsets.only(top: key == 'locationUrl' ? 12 : 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(
              TextSpan(text: label, children: [
                if (!optional)
                  TextSpan(
                      text: '*',
                      style: TextStyle(
                          color: _locked
                              ? const Color(0xFFFFB6AF)
                              : AppColors.red)),
              ]),
              style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: _locked ? AppColors.hintColor : AppColors.darkBlack)),
          const SizedBox(height: 8),
          TextFormField(
            key: Key('venue-update-$key'),
            controller: _controllers[key],
            enabled: !_locked && !_submitting,
            validator: (value) => _validate(key, value),
            style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 14,
                height: 1.4,
                color: _locked ? AppColors.hintColor : AppColors.darkBlack),
            keyboardType: key == 'description'
                ? TextInputType.multiline
                : key == 'locationUrl'
                    ? TextInputType.url
                    : key == 'venuePhone'
                        ? TextInputType.phone
                        : key == 'zipCode'
                            ? TextInputType.number
                            : TextInputType.text,
            minLines: key == 'description' ? 4 : 1,
            maxLines: key == 'description' ? 6 : 1,
            maxLength: key == 'description'
                ? 200
                : key == 'name'
                    ? 255
                    : null,
            buildCounter: key == 'name'
                ? (_,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null
                : null,
            inputFormatters: key == 'zipCode'
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6)
                  ]
                : null,
            decoration: OnboardingStyles.inputDecoration().copyWith(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              counterStyle: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 12,
                  color: AppColors.hintColor),
              fillColor: _locked ? const Color(0x80FFFFFF) : Colors.white,
              suffixIcon: _locked
                  ? const Icon(Icons.lock_outline,
                      size: 22, color: AppColors.hintColor)
                  : null,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 40, minHeight: 40),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFDDE5CC))),
            ),
          ),
          if (key == 'locationUrl') ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.help_outline,
                  size: 14, color: AppColors.hintColor),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(
                      'Copy & add your venue\u2019s location from Google Maps.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: _locked
                              ? const Color(0xFFB3B8A2)
                              : AppColors.hintColor))),
            ]),
          ],
        ]),
      );

  Widget _notice(IconData icon, Widget content,
          {Color borderColor = _accent, Color? iconColor, bool centerIcon = false}) =>
      Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
            crossAxisAlignment: centerIcon
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
          Icon(icon, size: 34, color: iconColor ?? borderColor),
          const SizedBox(width: 18),
          Expanded(child: content),
        ]),
      );

  Widget _pendingHeader() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _notice(
            Icons.check_circle,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE09A00),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('Pending Approval',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontFamily: 'Satoshi')))),
              const SizedBox(height: 2),
              const Text('Status: Under Review',
                  style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 18,
                      height: 1.3)),
              const SizedBox(height: 10),
              const Text(
                  'Your changes have been submitted to ACTIV Admin for approval.',
                  style: TextStyle(fontSize: 14, height: 1.4)),
            ]),
            borderColor: const Color(0xFF999E93),
            iconColor: const Color(0xFF77BB17)),
        _notice(
            Icons.info_outline,
            const Text(
                'Your current live venue details will remain visible to users until approval.',
                style: TextStyle(color: _accent, fontSize: 14, height: 1.4))),
      ]);

  String get _submittedOn {
    final date = DateTime.tryParse(
        (_request?['createdAt'] ?? _request?['created_at'] ?? '').toString());
    return date == null
        ? '-'
        : DateFormat('dd MMM yyyy,\nhh:mm a').format(date.toLocal());
  }

  Widget _reviewNotice() {
    if (!_pending) {
      return _notice(
          Icons.schedule,
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Changes will be reviewed',
                style: TextStyle(
                    color: _accent,
                    fontFamily: 'Satoshi',
                    fontSize: 18,
                    height: 1.3)),
            SizedBox(height: 12),
            Text(
                'Once submitted, our team will review your changes. You\u2019ll be notified after approval.',
                style: TextStyle(color: _accent, fontSize: 14, height: 1.4)),
          ]));
    }
    final content = [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Submitted on',
            style: TextStyle(
                color: _accent,
                fontFamily: 'Satoshi',
                fontSize: 16,
                height: 1.4)),
        const SizedBox(height: 8),
        Text(_submittedOn, style: const TextStyle(fontSize: 15, height: 1.3)),
      ]),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Review ETA',
            style: TextStyle(
                color: _accent,
                fontFamily: 'Satoshi',
                fontSize: 16,
                height: 1.4)),
        SizedBox(height: 8),
        Text('Usually within\n24 hours',
            style: TextStyle(fontSize: 15, height: 1.3)),
      ]),
    ];
    return _notice(
        Icons.schedule,
        LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(16) > 20
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        content.first,
                        const Divider(height: 32),
                        content.last
                      ])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 8, child: content.first),
                    Container(
                      width: 1,
                      height: 66,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: _accent.withValues(alpha: 0.45),
                    ),
                    Expanded(flex: 10, child: content.last)
                  ])),
        centerIcon: true);
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
        showLogo: false,
          child: Column(children: [
        Expanded(
            child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              height: 50,
                              child: Stack(alignment: Alignment.center, children: [
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                        onPressed: () => Navigator.pop(context),
                                        tooltip: 'Back',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 44, minHeight: 44),
                                        icon: const Icon(Icons.arrow_back))),
                                const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 48),
                                    child: Text('Update Venue Details',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontFamily: 'Satoshi',
                                            fontSize: 20,
                                            height: 1.25))),
                              ])),
                          if (_loading)
                            const Padding(
                                padding: EdgeInsets.all(40),
                                child:
                                    Center(child: CircularProgressIndicator()))
                          else if (_loadError != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 32),
                                child: Column(children: [
                                  Text(_loadError!,
                                      textAlign: TextAlign.center),
                                  TextButton.icon(
                                      onPressed: _loadVenue,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry')),
                                ]))
                          else if (_venue.isEmpty)
                            const Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: Text('No venue data found.'))
                          else ...[
                            if (_pending) _pendingHeader(),
                            if (_request?['status']?.toString().toLowerCase() ==
                                'rejected')
                              _notice(
                                  Icons.info_outline,
                                  Text(
                                      _request?['adminNotes']?.toString() ??
                                          'Your previous changes were not approved. Update your details and submit again.',
                                      style: const TextStyle(
                                          color: _accent, height: 1.5))),
                            SizedBox(height: _pending ? 24 : 32),
                            const Text(
                                'Changes will be reviewed by our team before going live.',
                                style: TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                    color: AppColors.black1)),
                            _field('name', 'Venue Name'),
                            _field('description', 'Description'),
                            _addressField(),
                            _field('flatBuilding',
                                'Flat/Building, Floor Number (optional)',
                                optional: true),
                            _field('venuePhone', 'Partner Phone Number'),
                            _field('city', 'City/Town'),
                            _field('state', 'State'),
                            _field('zipCode', 'Pin Code'),
                            if (_canEdit) _reviewNotice(),
                            if (_pending)
                              const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Row(children: [
                                    Icon(Icons.info_outline,
                                        size: 22, color: _accent),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            'You will be notified once our team reviews your changes.',
                                            style: TextStyle(
                                                color: _accent,
                                                fontSize: 12,
                                                height: 1.4))),
                                  ])),
                            if (_submissionError != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Text(_submissionError!,
                                      style: const TextStyle(
                                          color: AppColors.red, height: 1.5))),
                          ],
                        ])))),
        if (!_loading && _loadError == null && _venue.isNotEmpty)
          DecoratedBox(
              decoration: const BoxDecoration(
                  color: AppColors.yellowBottom,
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, -2))
                  ]),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: OnboardingButton(
                      label: _pending
                          ? 'Under Review'
                          : !_canEdit
                              ? 'View Only'
                              : 'Submit for Review',
                      loading: _submitting,
                      fontSize: 20,
                      borderRadius: 8,
                      disabledBackgroundColor: const Color(0xFF989D86),
                      disabledForegroundColor: const Color(0xFFE7ECD5),
                      icon: _pending ? Icons.schedule : null,
                      onPressed: _locked ? null : _submit))),
      ]));
}
