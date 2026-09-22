import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/delivery_model.dart';
import '../../models/driver_assignment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/enterprise_app_bar.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/delivery_card.dart';
import '../profile_screen.dart';
import 'delivery_detail_screen.dart';

class DriverPortalScreen extends StatefulWidget {
  const DriverPortalScreen({super.key});

  @override
  State<DriverPortalScreen> createState() => _DriverPortalScreenState();
}

class _DriverPortalScreenState extends State<DriverPortalScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _deliveryWatchGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final delivery = context.read<DeliveryProvider>();
      await delivery.loadDeliveries();
      await delivery.disconnectDriver();
      if (mounted) _startWatchingDeliveries();
    });
  }

  @override
  void dispose() {
    _deliveryWatchGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _resumeDeliveryUpdates();
    } else if (
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _deliveryWatchGeneration++;
    }
  }

  Future<void> _resumeDeliveryUpdates() async {
    await context
        .read<DeliveryProvider>()
        .loadDeliveries(showLoading: false);
    if (mounted) _startWatchingDeliveries();
  }

  void _startWatchingDeliveries() {
    final generation = ++_deliveryWatchGeneration;
    unawaited(_watchDeliveries(generation));
  }

  Future<void> _watchDeliveries(int generation) async {
    var retrySeconds = 2;
    while (mounted && generation == _deliveryWatchGeneration) {
      final success =
          await context.read<DeliveryProvider>().pollDeliveries();
      if (!mounted || generation != _deliveryWatchGeneration) return;
      if (success) {
        retrySeconds = 2;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      } else {
        await Future<void>.delayed(Duration(seconds: retrySeconds));
        retrySeconds = retrySeconds >= 15 ? 30 : retrySeconds * 2;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final delivery = context.watch<DeliveryProvider>();

    return Scaffold(
      appBar: EnterpriseAppBar(
        title: _selectedIndex == 0 ? 'Driver Radar' : 'My Deliveries',
        subtitle: auth.user?.name ?? 'Driver',
        actions: [
          AppBarIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () {
              if (_selectedIndex == 0 && delivery.isDriverConnected) {
                delivery.loadDriverOffers();
              } else {
                delivery.loadDeliveries(showLoading: false);
              }
            },
          ),
          const SizedBox(width: 4),
          AppBarIconButton(
            icon: Icons.account_circle_outlined,
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _DriverRadarPage(
            onOrderAccepted: () {
              setState(() => _selectedIndex = 1);
              delivery.loadDeliveries(showLoading: false);
            },
          ),
          const _DriverDeliveriesPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            delivery.loadDeliveries(showLoading: false);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_rounded),
            selectedIcon: Icon(Icons.radar_rounded, color: AppColors.accent),
            label: 'Radar',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(
              Icons.local_shipping_rounded,
              color: AppColors.accent,
            ),
            label: 'Deliveries',
          ),
        ],
      ),
    );
  }
}

class _DriverRadarPage extends StatefulWidget {
  final VoidCallback onOrderAccepted;

  const _DriverRadarPage({required this.onOrderAccepted});

  @override
  State<_DriverRadarPage> createState() => _DriverRadarPageState();
}

class _DriverRadarPageState extends State<_DriverRadarPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _radarController;
  Timer? _locationTimer;
  int _scanGeneration = 0;
  bool _isChangingConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _stopScanning();
    WidgetsBinding.instance.removeObserver(this);
    _radarController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopScanning();
      unawaited(context.read<DeliveryProvider>().disconnectDriver());
    }
  }

  void _startScanning() {
    _radarController.repeat();
    _locationTimer?.cancel();
    final generation = ++_scanGeneration;
    _pollOffersContinuously(generation);
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<DeliveryProvider>().updateDriverAvailabilityLocation();
      }
    });
  }

  void _stopScanning() {
    _scanGeneration++;
    _locationTimer?.cancel();
    _locationTimer = null;
    _radarController.stop();
  }

  Future<void> _pollOffersContinuously(int generation) async {
    var retrySeconds = 2;
    while (
        mounted &&
        generation == _scanGeneration &&
        context.read<DeliveryProvider>().isDriverConnected) {
      final success =
          await context.read<DeliveryProvider>().pollDriverOffers();
      if (!mounted || generation != _scanGeneration) return;
      if (success) {
        retrySeconds = 2;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      } else {
        await Future<void>.delayed(Duration(seconds: retrySeconds));
        retrySeconds = math.min(retrySeconds * 2, 30);
      }
    }
  }

  Future<void> _connect() async {
    setState(() => _isChangingConnection = true);
    final delivery = context.read<DeliveryProvider>();
    final connected = await delivery.connectDriver();
    if (!mounted) return;
    setState(() => _isChangingConnection = false);
    if (connected) {
      await delivery.loadDriverOffers();
      if (mounted) _startScanning();
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isChangingConnection = true);
    final disconnected =
        await context.read<DeliveryProvider>().disconnectDriver();
    if (!mounted) return;
    if (disconnected) _stopScanning();
    setState(() => _isChangingConnection = false);
  }

  Future<void> _openOffer(DeliveryOffer offer) async {
    _stopScanning();
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverOfferDetailScreen(offer: offer),
      ),
    );
    if (accepted == true && mounted) {
      widget.onOrderAccepted();
    } else if (
        mounted &&
        context.read<DeliveryProvider>().isDriverConnected) {
      _startScanning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = context.watch<DeliveryProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        if (delivery.isDriverConnected) {
          await delivery.loadDriverOffers();
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (!delivery.isDriverConnected)
            _OfflinePanel(
              isConnecting: _isChangingConnection,
              onConnect: _connect,
            )
          else ...[
            _RadarPanel(
              animation: _radarController,
              offerCount: delivery.driverOffers.length,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isChangingConnection ? null : _disconnect,
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text('Disconnect from delivery network'),
            ),
            const SizedBox(height: 18),
            SectionHeader(
              title: 'Incoming Orders',
              actionLabel: delivery.driverOffers.isEmpty
                  ? 'Scanning'
                  : '${delivery.driverOffers.length} found',
              horizontalPadding: 0,
            ),
            if (delivery.driverOffers.isEmpty)
              const _ScanningMessage()
            else
              ...delivery.driverOffers.map(
                (offer) => _RadarOfferTile(
                  offer: offer,
                  onTap: () => _openOffer(offer),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _OfflinePanel extends StatelessWidget {
  final bool isConnecting;
  final VoidCallback onConnect;

  const _OfflinePanel({
    required this.isConnecting,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 32),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(
              Icons.radar_rounded,
              size: 58,
              color: AppColors.accentLight,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'You are offline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect to the delivery network to become visible to nearby customers and receive orders.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: isConnecting ? null : onConnect,
            icon: isConnecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.power_settings_new_rounded),
            label: Text(isConnecting ? 'Connecting...' : 'Connect & Go Online'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPanel extends StatelessWidget {
  final Animation<double> animation;
  final int offerCount;

  const _RadarPanel({
    required this.animation,
    required this.offerCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 260,
            height: 260,
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, _) => CustomPaint(
                painter: _RadarPainter(
                  progress: animation.value,
                  offerCount: offerCount,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LiveDot(),
              SizedBox(width: 9),
              Text(
                'ONLINE • SCANNING WITHIN 1 KM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final int offerCount;

  const _RadarPainter({
    required this.progress,
    required this.offerCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final gridPaint = Paint()
      ..color = AppColors.accentLight.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, gridPaint);
    }
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      gridPaint,
    );

    final angle = progress * math.pi * 2;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 0.8,
        endAngle: angle,
        colors: [
          Colors.transparent,
          AppColors.accentLight.withValues(alpha: 0.45),
        ],
        transform: GradientRotation(angle - 0.8),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweepPaint);

    final beamPaint = Paint()
      ..color = AppColors.accentLight
      ..strokeWidth = 2;
    canvas.drawLine(
      center,
      Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      ),
      beamPaint,
    );

    canvas.drawCircle(
      center,
      7,
      Paint()..color = AppColors.accentLight,
    );

    final blipPositions = [
      const Offset(0.66, 0.34),
      const Offset(0.30, 0.62),
      const Offset(0.72, 0.70),
    ];
    for (var i = 0; i < math.min(offerCount, blipPositions.length); i++) {
      final point = Offset(
        size.width * blipPositions[i].dx,
        size.height * blipPositions[i].dy,
      );
      canvas.drawCircle(
        point,
        9,
        Paint()..color = AppColors.warning.withValues(alpha: 0.25),
      );
      canvas.drawCircle(point, 4, Paint()..color = AppColors.warning);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.offerCount != offerCount;
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: AppColors.live,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ScanningMessage extends StatelessWidget {
  const _ScanningMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Searching for nearby customer orders…',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarOfferTile extends StatelessWidget {
  final DeliveryOffer offer;
  final VoidCallback onTap;

  const _RadarOfferTile({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final seconds = offer.timeRemaining.inSeconds.clamp(0, 60);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.delivery.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        offer.distanceKm == null
                            ? 'New customer order'
                            : '${offer.distanceKm!.toStringAsFixed(1)} km to pickup',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${seconds}s',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverDeliveriesPage extends StatelessWidget {
  const _DriverDeliveriesPage();

  @override
  Widget build(BuildContext context) {
    final delivery = context.watch<DeliveryProvider>();
    final active = delivery.activeDeliveries;
    final completed = delivery.deliveries
        .where((item) => !item.isActive)
        .toList();

    return RefreshIndicator(
      onRefresh: () => delivery.loadDeliveries(showLoading: false),
      child: ListView(
        children: [
          if (active.isEmpty && completed.isEmpty)
            const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No deliveries yet',
              message:
                  'Accepted customer orders will appear here automatically.',
            ),
          if (active.isNotEmpty) ...[
            SectionHeader(
              title: 'Active Deliveries',
              actionLabel: '${active.length} active',
            ),
            ...active.map(
              (order) => DeliveryCard(
                delivery: order,
                onTap: () => _openDelivery(context, delivery, order),
              ),
            ),
          ],
          if (completed.isNotEmpty) ...[
            SectionHeader(
              title: 'Delivery History',
              actionLabel: '${completed.length} completed',
            ),
            ...completed.map(
              (order) => DeliveryCard(
                delivery: order,
                onTap: () => _openDelivery(context, delivery, order),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _openDelivery(
    BuildContext context,
    DeliveryProvider provider,
    DeliveryModel order,
  ) {
    provider.setActiveDelivery(order);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryDetailScreen()),
    );
  }
}

class DriverOfferDetailScreen extends StatefulWidget {
  final DeliveryOffer offer;

  const DriverOfferDetailScreen({super.key, required this.offer});

  @override
  State<DriverOfferDetailScreen> createState() =>
      _DriverOfferDetailScreenState();
}

class _DriverOfferDetailScreenState extends State<DriverOfferDetailScreen> {
  bool _isResponding = false;

  Future<void> _openDirections() async {
    final order = widget.offer.delivery;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${order.pickupLat},${order.pickupLng}'
      '&travelmode=driving',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open GPS directions')),
      );
    }
  }

  Future<void> _respond({required bool accept}) async {
    setState(() => _isResponding = true);
    final provider = context.read<DeliveryProvider>();
    final success = accept
        ? await provider.acceptDriverOffer(widget.offer.id)
        : await provider.rejectDriverOffer(widget.offer.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, accept);
      return;
    }
    setState(() => _isResponding = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Unable to update this order. Please try again.',
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.offer.delivery;
    final distance = widget.offer.distanceKm;

    return Scaffold(
      appBar: EnterpriseAppBar(
        title: order.name,
        subtitle: 'Incoming delivery request',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OfferSummaryCard(
              icon: Icons.person_outline_rounded,
              title: 'Customer',
              rows: [
                _DetailRow('Name', order.customerName),
                _DetailRow('Phone', order.customerPhone ?? 'Not provided'),
              ],
            ),
            const SizedBox(height: 14),
            _OfferSummaryCard(
              icon: Icons.route_outlined,
              title: 'Route',
              rows: [
                _DetailRow(
                  'Distance to pickup',
                  distance == null
                      ? 'Calculating'
                      : '${distance.toStringAsFixed(1)} km',
                ),
                _DetailRow(
                  'Pickup',
                  order.pickupAddress ??
                      '${order.pickupLat}, ${order.pickupLng}',
                ),
                _DetailRow(
                  'Destination',
                  order.deliveryAddress ??
                      '${order.deliveryLat}, ${order.deliveryLng}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openDirections,
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Open GPS Directions to Pickup'),
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(
                  Size(double.infinity, 52),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _OfferSummaryCard(
              icon: Icons.inventory_2_outlined,
              title: 'Parcel',
              rows: [
                _DetailRow('Size', order.parcelSize?.label ?? 'Parcel'),
                if (order.parcelWeightKg != null)
                  _DetailRow(
                    'Weight',
                    '${order.parcelWeightKg!.toStringAsFixed(1)} kg',
                  ),
                _DetailRow('Fragile', order.isFragile ? 'Yes' : 'No'),
                if (order.deliveryNotes != null)
                  _DetailRow('Instructions', order.deliveryNotes!),
                if (order.estimatedPrice != null)
                  _DetailRow(
                    'Estimated fare',
                    '${order.currencyCode ?? 'USD'} '
                        '${order.estimatedPrice!.toStringAsFixed(2)}',
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isResponding ? null : () => _respond(accept: false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed:
                      _isResponding ? null : () => _respond(accept: true),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    _isResponding ? 'Accepting...' : 'Accept Delivery',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);
}

class _OfferSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_DetailRow> rows;

  const _OfferSummaryCard({
    required this.icon,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      row.label,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
