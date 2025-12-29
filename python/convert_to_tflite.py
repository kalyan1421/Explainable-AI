import os
import tensorflow as tf

# --- CRITICAL FIX: Disable GPU/Metal for Conversion ---
# The TFLite converter is unstable on Mac GPUs. We force CPU mode.
os.environ['CUDA_VISIBLE_DEVICES'] = '-1'
try:
    # Hide GPU from TensorFlow explicitly
    tf.config.set_visible_devices([], 'GPU')
    print("✅ GPU disabled for conversion stability.")
except:
    pass
# ------------------------------------------------------

def convert():
    h5_path = '/Users/kalyan/Client project/Explainable AI/models/pneumonia_model.h5'
    saved_model_dir = '/Users/kalyan/Client project/Explainable AI/models/temp_saved_model'
    tflite_path = '/Users/kalyan/Client project/Explainable AI/models/pneumonia_model.tflite'

    print(f"1. Loading model from {h5_path}...")
    try:
        model = tf.keras.models.load_model(h5_path)
    except OSError:
        print(f"❌ Error: Could not find {h5_path}. Make sure you ran train.py first.")
        return

    # Step 2: Save as a native TensorFlow 'SavedModel' directory
    # This fixes the "missing attribute 'value'" error by freezing weights correctly
    print("2. converting to intermediate SavedModel format...")
    tf.saved_model.save(model, saved_model_dir)

    # Step 3: Convert the SavedModel to TFLite
    print("3. Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
    
    # Optional: Optimize for size (reduces file size, slightly slower)
    converter.optimizations = [tf.lite.Optimize.DEFAULT] 
    
    tflite_model = converter.convert()

    # Step 4: Write the file
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)

    print(f"\n🎉 Success! TFLite model saved to: {tflite_path}")
    print("👉 Now copy this file to your Flutter assets folder.")

if __name__ == "__main__":
    convert()