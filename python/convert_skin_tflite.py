import tensorflow as tf
import shutil
import os

# Paths
H5_MODEL_PATH = 'models/skin_cancer_model.h5'
SAVED_MODEL_DIR = 'models/temp_skin_cancer_saved_model' # Temporary directory
TFLITE_PATH = 'models/skin_cancer.tflite'

print(f"🔹 Loading Keras model from {H5_MODEL_PATH}...")
try:
    # 1. Load the .h5 model
    model = tf.keras.models.load_model(H5_MODEL_PATH)
    
    # 2. Re-save it as a TensorFlow 'SavedModel' (Folder structure)
    # This fixes the 'missing attribute value' error by crystallizing the graph
    print(f"🔹 Exporting to SavedModel format at {SAVED_MODEL_DIR}...")
    model.export(SAVED_MODEL_DIR) 
    # Note: If you are on an older TF version (<2.13) use: model.save(SAVED_MODEL_DIR, save_format='tf')

    # 3. Convert from the SavedModel directory instead of the Keras object
    print("🔹 Converting SavedModel to TFLite...")
    converter = tf.lite.TFLiteConverter.from_saved_model(SAVED_MODEL_DIR)

    # Optimization: Float16 Quantization
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()

    # 4. Save the TFLite file
    with open(TFLITE_PATH, 'wb') as f:
        f.write(tflite_model)

    print(f"✅ Success! TFLite model saved to {TFLITE_PATH}")

    # Cleanup temporary folder
    if os.path.exists(SAVED_MODEL_DIR):
        shutil.rmtree(SAVED_MODEL_DIR)
        print("🧹 Cleaned up temporary files.")

    # 5. Generate Labels File
    labels = ['akiec', 'bcc', 'bkl', 'df', 'mel', 'nv', 'vasc']
    with open('models/skin_labels.txt', 'w') as f:
        f.write('\n'.join(labels))
    print("✅ Labels saved to models/skin_labels.txt")

except Exception as e:
    print(f"\n❌ Error during conversion: {str(e)}")
    # Fallback for very specific version mismatches
    print("\n💡 Tip: If 'model.export' fails, try changing it to: model.save(SAVED_MODEL_DIR, save_format='tf')")