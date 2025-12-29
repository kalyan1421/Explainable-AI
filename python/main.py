from fastapi import FastAPI, File, UploadFile
import tensorflow as tf
import numpy as np
from PIL import Image
import io
import cv2
import base64
from xai_utils import make_gradcam_heatmap, process_heatmap_overlay

app = FastAPI()

# Load the trained model
# Ensure the path matches where train.py saved it
MODEL_PATH = "../models/pneumonia_model.h5"
model = tf.keras.models.load_model(MODEL_PATH)

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    # 1. Read and Process Image
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert('RGB')
    image = image.resize((224, 224))
    
    img_array = np.array(image)
    
    # IMPORTANT: Preprocessing must match training (rescale 1./255)
    img_batch = np.expand_dims(img_array, axis=0) / 255.0

    # 2. Make Prediction
    prediction = model.predict(img_batch)
    score = float(prediction[0][0]) # 0.0 to 1.0
    
    # 3. Generate Explainability (Grad-CAM)
    # "out_relu" is the last Conv layer in MobileNetV2
    heatmap = make_gradcam_heatmap(img_batch, model, last_conv_layer_name="out_relu")
    
    # Overlay heatmap on original image
    # Note: process_heatmap_overlay expects unscaled image (0-255)
    overlay_img = process_heatmap_overlay(img_array, heatmap)
    
    # Convert to Base64 to send to Flutter
    _, buffer = cv2.imencode('.jpg', overlay_img)
    heatmap_base64 = base64.b64encode(buffer).decode('utf-8')

    # Logic: Closer to 0 is Normal, Closer to 1 is Pneumonia
    result = "PNEUMONIA" if score > 0.5 else "NORMAL"
    confidence = score if score > 0.5 else 1 - score

    return {
        "prediction": result,
        "confidence": f"{confidence*100:.2f}%",
        "heatmap_base64": heatmap_base64
    }