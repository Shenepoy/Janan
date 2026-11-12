import 'dart:async';

import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_strings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

class MedicineSupplySummary extends StatefulWidget {
  const MedicineSupplySummary({
    super.key,
    required this.repository,
    required this.medicineId,
    required this.unit,
  });
  final HealthToolsRepository repository;
  final String medicineId;
  final String unit;
  @override
  State<MedicineSupplySummary> createState() => _MedicineSupplySummaryState();
}

class _MedicineSupplySummaryState extends State<MedicineSupplySummary> {
  late Stream<List<Map<String, Object?>>> _rows;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _rows = widget.repository.watchSupply(widget.medicineId);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant MedicineSupplySummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.database != widget.repository.database ||
        oldWidget.medicineId != widget.medicineId) {
      _rows = widget.repository.watchSupply(widget.medicineId);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    key: ValueKey((widget.repository.database, widget.medicineId)),
    stream: _rows,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Text('tools.loadError'.toolTr(context));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final estimate = widget.repository.supplyFromRows(
        snapshot.data!,
        widget.unit,
        DateTime.now(),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${'tools.stock'.toolTr(context)}: ${estimate.remaining?.toStringAsFixed(2) ?? 'tools.unknown'.toolTr(context)} ${'tools.options.${widget.unit}'.toolTr(context)}',
          ),
          const SizedBox(height: 8),
          Text(
            estimate.shortageAt == null
                ? 'tools.supply.${estimate.status}'.toolTr(context)
                : '${'tools.supply.shortage'.toolTr(context)}: ${DateFormat.yMMMd(context.locale.toString()).add_Hm().format(estimate.shortageAt!)}',
          ),
          Text(
            'tools.supply.basis'.toolTr(context),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}
