import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/delivery_request.dart';
import '../../models/driver_assignment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/geo_utils.dart';
import '../../widgets/address_search_field.dart';
import '../../widgets/common/enterprise_app_bar.dart';
import '../../widgets/driver_avatar.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _weightController = TextEditingController(text: '1.0');
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _driverSearchController = TextEditingController();

  GeocodingResult? _pickup;
  GeocodingResult? _destination;
  ParcelSize _parcelSize = ParcelSize.small;
  bool _isFragile = false;
  bool _scheduleDelivery = false;
  DateTime? _scheduledAt;
  bool _isSubmitting = false;
  bool _choosePreferredDriver = false;
  AvailableDriver? _selectedDriver;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _driverSearchController.dispose();
    super.dispose();
  }

  DeliveryEstimate? get _estimate {
    if (_pickup == null || _destination == null) return null;
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) return null;

    final distance = haversineKm(
      _pickup!.latitude,
      _pickup!.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );
    return DeliveryEstimate.calculate(
      distanceKm: distance,
      parcelSize: _parcelSize,
      weightKg: weight,
      isFragile: _isFragile,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickup == null) {
      _showError('Please select a pickup address');
      return;
    }
    if (_destination == null) {
      _showError('Please select a delivery address');
      return;
    }
    if (_scheduleDelivery && _scheduledAt == null) {
      _showError('Please choose a delivery date and time');
      return;
    }
    if (_choosePreferredDriver && _selectedDriver == null) {
      _showError('Please select a preferred driver');
      return;
    }

    final estimate = _estimate;
    if (estimate == null) {
      _showError('Unable to calculate the delivery estimate');
      return;
    }

    setState(() => _isSubmitting = true);

    final request = DeliveryRequest(
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      pickupLat: _pickup!.latitude,
      pickupLng: _pickup!.longitude,
      deliveryLat: _destination!.latitude,
      deliveryLng: _destination!.longitude,
      pickupAddress: _pickup!.displayName,
      deliveryAddress: _destination!.displayName,
      parcelSize: _parcelSize,
      weightKg: double.parse(_weightController.text),
      parcelDescription: _descriptionController.text.trim(),
      isFragile: _isFragile,
      deliveryNotes: _notesController.text.trim(),
      scheduledAt: _scheduleDelivery ? _scheduledAt : null,
      estimatedDistanceKm: estimate.distanceKm,
      estimatedPrice: estimate.price,
      preferredDriverId: _selectedDriver?.id,
    );

    final created = await context.read<DeliveryProvider>().createDelivery(
      request,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${created.name} created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      _showError('Unable to create the order. Please try again.');
    }
  }

  Future<void> _searchDrivers() async {
    await context.read<DeliveryProvider>().searchAvailableDrivers(
      search: _driverSearchController.text,
      pickupLat: _pickup?.latitude,
      pickupLng: _pickup?.longitude,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _chooseSchedule() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now.add(const Duration(hours: 2));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isBefore(now.add(const Duration(minutes: 30)))) {
      _showError('Scheduled delivery must be at least 30 minutes from now');
      return;
    }
    setState(() => _scheduledAt = selected);
  }

  IconData _parcelIcon(ParcelSize size) => switch (size) {
    ParcelSize.document => Icons.description_outlined,
    ParcelSize.small => Icons.inventory_2_outlined,
    ParcelSize.medium => Icons.all_inbox_outlined,
    ParcelSize.large => Icons.widgets_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;
    final currency = NumberFormat.simpleCurrency(name: 'USD');
    final deliveryProvider = context.watch<DeliveryProvider>();

    return Scaffold(
      appBar: EnterpriseAppBar(
        title: 'New Order',
        subtitle: 'Book a secure delivery',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OrderSection(
                icon: Icons.person_outline_rounded,
                title: 'Contact details',
                subtitle: 'Who should we contact about this delivery?',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Please enter a contact name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: 'Include country code',
                      ),
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        if (phone.isEmpty) return 'Please enter a phone number';
                        if (phone.length < 7) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _OrderSection(
                icon: Icons.route_outlined,
                title: 'Pickup and destination',
                subtitle: 'Select both addresses to calculate your estimate.',
                child: Column(
                  children: [
                    AddressSearchField(
                      label: 'Pickup address',
                      icon: Icons.trip_origin_rounded,
                      onSelected: (result) {
                        setState(() {
                          _pickup = result;
                          _selectedDriver = null;
                        });
                        if (_choosePreferredDriver) _searchDrivers();
                      },
                    ),
                    const SizedBox(height: 14),
                    AddressSearchField(
                      label: 'Delivery address',
                      icon: Icons.location_on_outlined,
                      onSelected: (result) =>
                          setState(() => _destination = result),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _OrderSection(
                icon: Icons.local_shipping_outlined,
                title: 'Choose a driver',
                subtitle:
                    'Request a preferred driver or notify drivers within 1 km.',
                child: Column(
                  children: [
                    _AssignmentChoice(
                      icon: Icons.radar_rounded,
                      title: 'Find a nearby driver',
                      subtitle: 'First nearby driver to accept gets the order',
                      selected: !_choosePreferredDriver,
                      onTap: () {
                        setState(() {
                          _choosePreferredDriver = false;
                          _selectedDriver = null;
                        });
                        deliveryProvider.clearAvailableDrivers();
                      },
                    ),
                    const SizedBox(height: 10),
                    _AssignmentChoice(
                      icon: Icons.person_search_outlined,
                      title: 'Choose a preferred driver',
                      subtitle: 'The driver has 60 seconds to accept',
                      selected: _choosePreferredDriver,
                      onTap: () {
                        setState(() => _choosePreferredDriver = true);
                        _searchDrivers();
                      },
                    ),
                    if (_choosePreferredDriver) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _driverSearchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchDrivers(),
                        decoration: InputDecoration(
                          labelText: 'Search active drivers',
                          hintText: 'Enter driver name',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            onPressed: _searchDrivers,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (deliveryProvider.isLoadingDrivers)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        )
                      else if (deliveryProvider.availableDrivers.isEmpty)
                        const _DriverSearchMessage(
                          message:
                              'No connected and available drivers found.',
                        )
                      else
                        ...deliveryProvider.availableDrivers.take(5).map(
                              (driver) => _DriverOption(
                                driver: driver,
                                selected: _selectedDriver?.id == driver.id,
                                onTap: () =>
                                    setState(() => _selectedDriver = driver),
                              ),
                            ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _OrderSection(
                icon: Icons.inventory_2_outlined,
                title: 'Parcel details',
                subtitle: 'Accurate details help us assign the right vehicle.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ParcelSize.values
                          .map(
                            (size) => _ParcelOption(
                              icon: _parcelIcon(size),
                              label: size.label,
                              selected: _parcelSize == size,
                              onTap: () => setState(() => _parcelSize = size),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,3}(\.\d{0,2})?'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Approximate weight',
                        suffixText: 'kg',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final weight = double.tryParse(value ?? '');
                        if (weight == null || weight <= 0) {
                          return 'Enter a valid parcel weight';
                        }
                        if (weight > 100) {
                          return 'Contact support for parcels over 100 kg';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Contents',
                        hintText: 'e.g. Books, clothing, electronics',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isFragile,
                      activeTrackColor: AppColors.accentLight,
                      title: const Text('Fragile item'),
                      subtitle: const Text('Requires careful handling'),
                      secondary: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                      onChanged: (value) => setState(() => _isFragile = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _OrderSection(
                icon: Icons.schedule_outlined,
                title: 'Delivery timing',
                subtitle: 'Send it now or reserve a time within 30 days.',
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _scheduleDelivery,
                      activeTrackColor: AppColors.accentLight,
                      title: const Text('Schedule for later'),
                      subtitle: Text(
                        _scheduleDelivery
                            ? 'Choose your preferred delivery time'
                            : 'Pickup as soon as a driver is available',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _scheduleDelivery = value;
                          if (!value) _scheduledAt = null;
                        });
                      },
                    ),
                    if (_scheduleDelivery) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _chooseSchedule,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          _scheduledAt == null
                              ? 'Choose date and time'
                              : DateFormat(
                                  'EEE, d MMM • h:mm a',
                                ).format(_scheduledAt!),
                        ),
                        style: const ButtonStyle(
                          minimumSize: WidgetStatePropertyAll(
                            Size(double.infinity, 50),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      maxLength: 250,
                      decoration: const InputDecoration(
                        labelText: 'Delivery instructions (optional)',
                        hintText: 'Gate code, landmark, or handling notes',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _EstimateCard(
                estimate: estimate,
                currency: currency,
                parcelLabel: _parcelSize.label,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline_rounded),
                label: Text(
                  _isSubmitting
                      ? 'Creating order...'
                      : estimate == null
                      ? 'Review and create order'
                      : 'Confirm order • ${currency.format(estimate.price)}',
                ),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(
                    Size(double.infinity, 54),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'PIN-secured handover and live tracking included',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _OrderSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AssignmentChoice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _AssignmentChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.08)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverOption extends StatelessWidget {
  final AvailableDriver driver;
  final bool selected;
  final VoidCallback onTap;

  const _DriverOption({
    required this.driver,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final distance = driver.distanceKm == null
        ? 'Online and available'
        : '${driver.distanceKm!.toStringAsFixed(1)} km from pickup';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.successBg : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.success : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                DriverAvatar(
                  name: driver.name,
                  imageBase64: driver.profileImageBase64,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$distance • ${driver.activeDeliveryCount} active',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: selected ? AppColors.success : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverSearchMessage extends StatelessWidget {
  final String message;

  const _DriverSearchMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ParcelOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ParcelOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.1)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 132,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.accentDark
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  final DeliveryEstimate? estimate;
  final NumberFormat currency;
  final String parcelLabel;

  const _EstimateCard({
    required this.estimate,
    required this.currency,
    required this.parcelLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (estimate == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.info),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Select pickup and delivery addresses to see the distance and estimated fare.',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
              SizedBox(width: 9),
              Text(
                'Order estimate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _EstimateRow(
            label: 'Route distance',
            value: formatDistance(estimate!.distanceKm),
          ),
          const SizedBox(height: 8),
          _EstimateRow(label: 'Parcel', value: parcelLabel),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated total',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                currency.format(estimate!.price),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Final fare may change if the route or parcel details change.',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EstimateRow extends StatelessWidget {
  final String label;
  final String value;

  const _EstimateRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
