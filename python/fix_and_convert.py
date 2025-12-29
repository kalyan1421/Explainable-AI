import os
import tensorflow as tf

# 1. Force CPU (Critical for Mac Stability)
os.environ['CUDA_VISIBLE_DEVICES'] = '-1'

def convert_robust():
    h5_path = '../models/pneumonia_model.h5'
    tflite_path = '../models/pneumonia_model.tflite'
    
    print(f"1. Loading Model from {h5_path}...")
    try:
        model = tf.keras.models.load_model(h5_path)
    except Exception as e:
        print(f"Error loading model: {e}")
        return

    # 2. Create a 'Concrete Function'
    # This effectively freezes the model into a static graph with a fixed input shape.
    # It bypasses the dynamic reading errors you are seeing.
    print("2. Generating Concrete Function...")
    
    @tf.function
    def inference_func(input_data):
        return model(input_data)
    
    # Define the exact input shape: [Batch=1, Height=224, Width=224, Channels=3]
    input_spec = tf.TensorSpec([1, 224, 224, 3], tf.float32)
    concrete_func = inference_func.get_concrete_function(input_spec)

    # 3. Convert using the Concrete Function
    print("3. Converting...")
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    
    # Standard optimizations
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    try:
        tflite_model = converter.convert()
        
        # 4. Save
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        print(f"\n✅ SUCCESS! Model saved to {tflite_path}")
        print("👉 Copy this file to your Flutter 'assets/' folder.")
        
    except Exception as e:
        print(f"\n❌ Conversion failed: {e}")
        print("Alternative: Upload your 'pneumonia_model.h5' to Google Colab and convert it there.")

if __name__ == "__main__":
    convert_robust()