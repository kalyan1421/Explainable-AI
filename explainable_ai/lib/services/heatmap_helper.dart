import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class HeatmapHelper {
  static Uint8List generateHeatmap(
    List<double> featureMap, 
    List<double> weights,    
    int size,                
    int channels,            
    int originalWidth,
    int originalHeight
  ) {
    // 1. Compute weighted sum (CAM)
    List<double> camGrid = List.filled(size * size, 0.0);

    for (int i = 0; i < size * size; i++) {
      double sum = 0.0;
      for (int k = 0; k < channels; k++) {
        // Safe check to avoid index errors
        int featIndex = i * channels + k;
        if (featIndex < featureMap.length && k < weights.length) {
          sum += featureMap[featIndex] * weights[k];
        }
      }
      // CRITICAL FIX: Apply ReLU immediately. 
      // If sum is negative (AI says "No Pneumonia here"), make it 0.0.
      camGrid[i] = max(0.0, sum); 
    }

    // 2. Find Max Value for Normalization (Ignore Min, base is 0)
    double maxVal = camGrid.reduce(max);
    
    // Avoid divide by zero if the whole image is 0 (No detection)
    if (maxVal <= 0) maxVal = 1.0; 

    // 3. Create Heatmap Image
    img.Image lowResHeatmap = img.Image(width: size, height: size);
    
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        double val = camGrid[y * size + x];
        
        // Normalize: 0 to 1 based on the hottest spot
        double normVal = val / maxVal;
        
        // Threshold: If importance is very low (< 20%), make it transparent to clean up noise
        if (normVal < 0.2) normVal = 0.0;

        // Color Mapping:
        // Alpha (Transparency) scales with importance
        int alpha = (normVal * 200).toInt().clamp(0, 255); 
        
        // Color: Pure Red (255, 0, 0)
        lowResHeatmap.setPixelRgba(x, y, 255, 0, 0, alpha);
      }
    }

    // 4. Resize to match X-Ray
    img.Image highResHeatmap = img.copyResize(
      lowResHeatmap, 
      width: originalWidth, 
      height: originalHeight, 
      interpolation: img.Interpolation.linear 
    );

    return img.encodePng(highResHeatmap);
  }
}