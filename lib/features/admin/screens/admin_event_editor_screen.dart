import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/event_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../events/providers/events_provider.dart';

class AdminEventEditorScreen extends ConsumerStatefulWidget {
  final String? eventId;
  const AdminEventEditorScreen({super.key, this.eventId});

  @override
  ConsumerState<AdminEventEditorScreen> createState() =>
      _AdminEventEditorScreenState();
}

class _AdminEventEditorScreenState
    extends ConsumerState<AdminEventEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _venueCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _capacityCtrl;
  late TextEditingController _imageCtrl;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  String _selectedCategory = 'Navratri';
  bool _loading = false;
  bool _initialized = false;
  EventModel? _existingEvent;

  final _categories = ['Navratri', 'Dandiya', 'Cultural', 'Workshop'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _venueCtrl = TextEditingController();
    _timeCtrl = TextEditingController(text: '7:30 PM - 12:30 AM');
    _priceCtrl = TextEditingController(text: '500');
    _capacityCtrl = TextEditingController(text: '1000');
    _imageCtrl = TextEditingController(
      text:
          'https://images.unsplash.com/photo-1574169208507-84376144848b?w=800',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && widget.eventId != null && widget.eventId!.isNotEmpty) {
      _loadExistingEvent(widget.eventId!);
      _initialized = true;
    }
  }

  Future<void> _loadExistingEvent(String id) async {
    setState(() => _loading = true);
    try {
      final event = await ref.read(eventDetailProvider(id).future);
      _existingEvent = event;
      _titleCtrl.text = event.title;
      _descCtrl.text = event.description;
      _venueCtrl.text = event.venue;
      _timeCtrl.text = event.time;
      _priceCtrl.text = event.price.toStringAsFixed(0);
      _capacityCtrl.text = event.capacity.toString();
      _imageCtrl.text = event.image ?? '';
      _selectedDate = event.date;
      if (_categories.contains(event.category)) {
        _selectedCategory = event.category!;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    _timeCtrl.dispose();
    _priceCtrl.dispose();
    _capacityCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final isEditing = _existingEvent != null;

      final event = EventModel(
        id: isEditing ? _existingEvent!.id : '',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        venue: _venueCtrl.text.trim(),
        date: _selectedDate,
        time: _timeCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        capacity: int.tryParse(_capacityCtrl.text.trim()) ?? 100,
        bookedCount: isEditing ? _existingEvent!.bookedCount : 0,
        category: _selectedCategory,
        image: _imageCtrl.text.trim().isNotEmpty
            ? _imageCtrl.text.trim()
            : null,
        isFavourite: isEditing ? _existingEvent!.isFavourite : false,
        createdAt: isEditing ? _existingEvent!.createdAt : DateTime.now(),
      );

      if (isEditing) {
        await ref.read(eventsProvider.notifier).updateEvent(event);
      } else {
        await ref.read(eventsProvider.notifier).addEvent(event);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Event updated successfully' : 'Event created successfully',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user?.isAdmin != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(child: Text('Administrator privileges required.')),
      );
    }

    final isEditing = widget.eventId != null && widget.eventId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Garba Event' : 'Create Garba Event'),
      ),
      body: _loading && _existingEvent == null && isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Event Title *',
                        hintText: 'e.g. Navratri Dandiya Raas 2026',
                        prefixIcon: Icon(Icons.event),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        hintText: 'Full festival and program details...',
                        prefixIcon: Icon(Icons.description),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _venueCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Venue / Location *',
                        hintText: 'e.g. GMDC Ground, Ahmedabad',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    // Date & Time
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Event Date *',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _timeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Time *',
                              hintText: 'e.g. 8:00 PM',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Price & Capacity
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ticket Price (₹) *',
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                            validator: (v) => (v == null || double.tryParse(v) == null)
                                ? 'Valid price required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _capacityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Capacity (Seats) *',
                              prefixIcon: Icon(Icons.people),
                            ),
                            validator: (v) => (v == null || int.tryParse(v) == null)
                                ? 'Valid capacity required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCategory = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _imageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cover Image URL',
                        hintText: 'https://...',
                        prefixIcon: Icon(Icons.image),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _loading ? null : _saveEvent,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Update Event' : 'Create Event'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
