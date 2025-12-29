# # backend/app/main.py
# from fastapi import FastAPI, UploadFile, File, HTTPException
# from fastapi.middleware.cors import CORSMiddleware
# from pydantic import BaseModel
# import numpy as np
# import pickle
# import base64
# from typing import List, Dict, Optional
# import io
# from PIL import Image

# app = FastAPI(title="Explainable Healthcare AI API")

# # CORS configuration
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=["*"],
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )

# # Load pre-trained models (example)
# # model = pickle.load(open('data/models/disease_model.pkl', 'rb'))

# class PatientData(BaseModel):
#     age: int
#     gender: str
#     symptoms: List[str]
#     vital_signs: Dict[str, float]
#     medical_history: Optional[List[str]] = []

# class PredictionResponse(BaseModel):
#     prediction: str
#     confidence: float
#     explanation: Dict
#     risk_factors: List[Dict]
#     recommendations: List[str]

# @app.get("/")
# async def root():
#     return {"message": "Explainable Healthcare AI API", "status": "running"}

# @app.post("/api/predict/disease")
# async def predict_disease(patient_data: PatientData):
#     """
#     Predict disease based on patient data with explanations
#     """
#     try:
#         # Prepare features
#         features = prepare_features(patient_data)
        
#         # Make prediction (mock example)
#         prediction_prob = 0.87  # Replace with actual model prediction
#         predicted_class = "Pneumonia"
        
#         # Generate SHAP explanations
#         explanation = generate_shap_explanation(features)
        
#         # Get risk factors
#         risk_factors = identify_risk_factors(patient_data, explanation)
        
#         # Generate recommendations
#         recommendations = generate_recommendations(predicted_class, risk_factors)
        
#         return PredictionResponse(
#             prediction=predicted_class,
#             confidence=prediction_prob,
#             explanation=explanation,
#             risk_factors=risk_factors,
#             recommendations=recommendations
#         )
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))

# @app.post("/api/analyze/xray")
# async def analyze_xray(file: UploadFile = File(...)):
#     """
#     Analyze chest X-ray image with visual explanations
#     """
#     try:
#         # Read image
#         contents = await file.read()
#         image = Image.open(io.BytesIO(contents))
        
#         # Preprocess image
#         processed_image = preprocess_image(image)
        
#         # Make prediction (mock)
#         prediction = "Pneumonia"
#         confidence = 0.87
        
#         # Generate attention map or Grad-CAM
#         heatmap = generate_gradcam(processed_image)
        
#         # Convert heatmap to base64
#         heatmap_base64 = image_to_base64(heatmap)
        
#         return {
#             "prediction": prediction,
#             "confidence": confidence,
#             "heatmap": heatmap_base64,
#             "affected_regions": ["Lower right lobe", "Middle left lobe"],
#             "explanation": "Model detected opacity patterns consistent with pneumonia"
#         }
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))

# @app.post("/api/explain/lime")
# async def explain_with_lime(patient_data: PatientData):
#     """
#     Generate LIME explanation for prediction
#     """
#     try:
#         features = prepare_features(patient_data)
#         lime_explanation = generate_lime_explanation(features)
        
#         return {
#             "feature_importance": lime_explanation['importance'],
#             "visualization": lime_explanation['plot_base64'],
#             "top_features": lime_explanation['top_features']
#         }
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))

# # Helper functions
# def prepare_features(patient_data: PatientData) -> np.ndarray:
#     """Prepare features from patient data"""
#     # Mock implementation
#     return np.array([patient_data.age, len(patient_data.symptoms)])

# def generate_shap_explanation(features: np.ndarray) -> Dict:
#     """Generate SHAP values for explanation"""
#     # Mock SHAP values
#     return {
#         "feature_names": ["Age", "Symptom Count", "Blood Pressure"],
#         "shap_values": [0.15, 0.42, 0.23],
#         "base_value": 0.5
#     }

# def identify_risk_factors(patient_data: PatientData, explanation: Dict) -> List[Dict]:
#     """Identify key risk factors from explanation"""
#     return [
#         {"factor": "Persistent Cough", "impact": "High", "value": 0.42},
#         {"factor": "Age", "impact": "Medium", "value": 0.15},
#         {"factor": "Fever Duration", "impact": "Medium", "value": 0.23}
#     ]

# def generate_recommendations(prediction: str, risk_factors: List[Dict]) -> List[str]:
#     """Generate clinical recommendations"""
#     return [
#         "Immediate chest X-ray recommended",
#         "Monitor oxygen saturation levels",
#         "Consider antibiotic treatment",
#         "Follow-up in 48 hours"
#     ]

# def preprocess_image(image: Image.Image) -> np.ndarray:
#     """Preprocess medical image"""
#     # Resize and normalize
#     image = image.resize((224, 224))
#     img_array = np.array(image) / 255.0
#     return np.expand_dims(img_array, axis=0)

# def generate_gradcam(image: np.ndarray) -> np.ndarray:
#     """Generate Grad-CAM heatmap"""
#     # Mock heatmap generation
#     return np.random.rand(224, 224)

# def image_to_base64(image: np.ndarray) -> str:
#     """Convert numpy array to base64 string"""
#     img = Image.fromarray((image * 255).astype(np.uint8))
#     buffer = io.BytesIO()
#     img.save(buffer, format="PNG")
#     return base64.b64encode(buffer.getvalue()).decode()

# def generate_lime_explanation(features: np.ndarray) -> Dict:
#     """Generate LIME explanation"""
#     # Mock LIME explanation
#     return {
#         "importance": {"Age": 0.15, "Symptoms": 0.42, "BP": 0.23},
#         "plot_base64": "mock_base64_string",
#         "top_features": ["Symptoms", "BP", "Age"]
#     }

# if __name__ == "__main__":
#     import uvicorn
#     uvicorn.run(app, host="0.0.0.0", port=8000)


from fastapi import FastAPI, UploadFile, File
import torch
from PIL import Image
import io
import numpy as np
import torchvision.transforms as transforms
from model import PneumoniaModel
from gradcam import GradCAM

app = FastAPI()

device = "cuda" if torch.cuda.is_available() else "cpu"

model = PneumoniaModel().to(device)
model.load_state_dict(torch.load("pneumonia_model.pth", map_location=device))
model.eval()

transform = transforms.Compose([
    transforms.Resize((224,224)),
    transforms.Grayscale(num_output_channels=3),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

gradcam = GradCAM(model, model.model.layer4)

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    image = Image.open(io.BytesIO(await file.read())).convert("RGB")
    x = transform(image).unsqueeze(0).to(device)

    with torch.no_grad():
        logits = model(x)
        probs = torch.softmax(logits, dim=1).cpu().numpy()[0]

    pred_class = int(np.argmax(probs))
    cam = gradcam.generate(x, pred_class)

    return {
        "prediction": "PNEUMONIA" if pred_class == 1 else "NORMAL",
        "confidence": float(probs[pred_class]),
        "gradcam": cam.tolist()
    }
