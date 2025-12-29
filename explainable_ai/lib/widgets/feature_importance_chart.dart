import 'package:flutter/material.dart';

class FeatureImportanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> features;
  final String title; // Added this parameter

  const FeatureImportanceChart({
    Key? key, 
    required this.features,
    this.title = "Feature Contribution", // Default value
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Normalize values for visualization (0 to 1 relative to max)
    double maxVal = 0.0;
    if (features.isNotEmpty) {
      maxVal = features.map((e) => e['importance'] as double).reduce((a, b) => a > b ? a : b);
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            ...features.map((item) {
              double relativeImp = maxVal > 0 ? (item['importance'] / maxVal) : 0;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(item['feature'], style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(height: 10, color: Colors.grey.shade200),
                          FractionallySizedBox(
                            widthFactor: relativeImp,
                            child: Container(height: 10, color: Colors.blueAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}