from fastapi import APIRouter, UploadFile, File, HTTPException
from PIL import Image
import io
import torch
import torchvision.transforms as transforms
import numpy as np

from model import PneumoniaModel
from gradcam import GradCAM
from app.models.ml_models import SkinCancerModel

router = APIRouter()

# Pneumonia Model Initialization
device = "cuda" if torch.cuda.is_available() else "cpu"
pneumonia_model = PneumoniaModel().to(device)
pneumonia_model.load_state_dict(torch.load("models/pneumonia_model.pth", map_location=device))
pneumonia_model.eval()

transform = transforms.Compose([
    transforms.Resize((224,224)),
    transforms.Grayscale(num_output_channels=3),
    transforms.ToTensor(),
    transforms.Normalize([0.5]*3, [0.5]*3)
])

gradcam = GradCAM(pneumonia_model, pneumonia_model.model.layer4)

# Skin Cancer Model Initialization
skin_cancer_model = SkinCancerModel(model_path='models/skin_cancer.tflite', labels_path='models/skin_labels.txt')

@router.post("/predict/pneumonia")
async def predict_pneumonia(file: UploadFile = File(...)):
    try:
        image = Image.open(io.BytesIO(await file.read())).convert("RGB")
        x = transform(image).unsqueeze(0).to(device)

        with torch.no_grad():
            logits = pneumonia_model(x)
            probs = torch.softmax(logits, dim=1).cpu().numpy()[0]

        pred_class = int(np.argmax(probs))
        cam = gradcam.generate(x, pred_class)

        return {
            "prediction": "PNEUMONIA" if pred_class == 1 else "NORMAL",
            "confidence": float(probs[pred_class]),
            "gradcam": cam.tolist()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/predict/skin_cancer")
async def predict_skin_cancer(file: UploadFile = File(...)):
    try:
        image = Image.open(io.BytesIO(await file.read())).convert("RGB")
        prediction = skin_cancer_model.predict(image)
        return prediction
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
