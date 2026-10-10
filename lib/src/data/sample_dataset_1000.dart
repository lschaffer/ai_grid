import 'dart:convert';
import 'dart:math';

/// Provides a realistic 1,000-row enterprise sales dataset for testing and demonstration.
class SampleSalesData {
  SampleSalesData._();

  static const List<String> regions = [
    'Africa',
    'North America',
    'Europe',
    'Asia',
    'South America',
    'Oceania',
  ];

  static const List<String> products = [
    'Eco Max',
    'Eco Supreme',
    'Eco Star',
    'Eco Pro',
    'Eco Ultra',
  ];

  static const List<String> sectors = [
    'Health',
    'Energy',
    'Telecom',
    'Banking',
    'Manufacturing',
    'Retail',
    'Aerospace',
    'Technology',
  ];

  static const List<String> statuses = [
    'Completed',
    'Shipped',
    'Processing',
    'Pending',
  ];

  /// Generates 1,000 deterministic sales records.
  static List<Map<String, dynamic>> generate1000Rows({int count = 1000}) {
    final rand = Random(42); // Deterministic seed for reproducible testing
    final List<Map<String, dynamic>> rows = [];

    for (int i = 1; i <= count; i++) {
      final region = regions[rand.nextInt(regions.length)];
      final product = products[rand.nextInt(products.length)];
      final sector = sectors[rand.nextInt(sectors.length)];
      final status = statuses[rand.nextInt(statuses.length)];

      final amount = 1000 + rand.nextInt(45000) + (rand.nextInt(100) / 100.0);
      final month = (rand.nextInt(12) + 1).toString().padLeft(2, '0');
      final day = (rand.nextInt(28) + 1).toString().padLeft(2, '0');
      final date = '2026-$month-$day';

      rows.add({
        'orderId': 1000 + i,
        'region': region,
        'product': product,
        'saleAmount': double.parse(amount.toStringAsFixed(2)),
        'sector': sector,
        'status': status,
        'date': date,
      });
    }

    return rows;
  }

  /// Converts the 1,000 rows into an indented JSON string.
  static String generateJson({int count = 1000}) {
    final data = generate1000Rows(count: count);
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
