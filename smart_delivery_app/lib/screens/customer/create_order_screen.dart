import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/address_search_field.dart';
import '../../widgets/common/enterprise_app_bar.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  GeocodingResult? _pickup;
  GeocodingResult? _destination;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) _nameController.text = user.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (_pickup == null) {
      _showError('Please select a pickup address');
      return;
    }
    if (_destination == null) {
      _showError('Please select a delivery address');
      return;
    }

    setState(() => _isSubmitting = true);

    final created = await context.read<DeliveryProvider>().createDelivery(
          customerName: name,
          customerPhone: _phoneController.text.trim(),
          pickupLat: _pickup!.latitude,
          pickupLng: _pickup!.longitude,
          deliveryLat: _destination!.latitude,
          deliveryLng: _destination!.longitude,
          pickupAddress: _pickup!.displayName,
          deliveryAddress: _destination!.displayName,
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
      _showError(
        context.read<DeliveryProvider>().error ?? 'Failed to create order',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EnterpriseAppBar(
        title: 'New Order',
        subtitle: 'Create a delivery request',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Search and select addresses from the map suggestions.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  AddressSearchField(
                    label: 'Pickup Address',
                    icon: Icons.store_outlined,
                    onSelected: (result) =>
                        setState(() => _pickup = result),
                  ),
                  const SizedBox(height: 14),
                  AddressSearchField(
                    label: 'Delivery Address',
                    icon: Icons.home_outlined,
                    onSelected: (result) =>
                        setState(() => _destination = result),
                  ),
                ],
              ),
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
                  : const Icon(Icons.add_circle_outline_rounded),
              label: Text(_isSubmitting ? 'Creating...' : 'Create Order'),
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(double.infinity, 52)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
