import tflite_runtime.interpreter as tflite
from PIL import Image
import numpy as np
import os

class SkinCancerModel:
    def __init__(self, model_path='models/skin_cancer.tflite', labels_path='models/skin_labels.txt'):
        self.interpreter = tflite.Interpreter(model_path=model_path)
        self.interpreter.allocate_tensors()
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()
        
        with open(labels_path, 'r') as f:
            self.labels = [line.strip() for line in f.readlines()]
            
        self.label_map = {
            'akiec': 'Actinic keratoses',
            'bcc': 'Basal cell carcinoma',
            'bkl': 'Benign keratosis',
            'df': 'Dermatofibroma',
            'mel': 'Melanoma',
            'nv': 'Nevus',
            'vasc': 'Vascular lesion'
        }
        self.full_labels = [self.label_map.get(label, label) for label in self.labels]

    def predict(self, image: Image.Image):
        # Resize to 224x224
        resized_image = image.resize((224, 224))

        # Normalize to [-1, 1] for MobileNetV2
        input_data = np.array(resized_image, dtype=np.float32)
        input_data = (input_data / 255.0 - 0.5) * 2.0
        input_data = np.expand_dims(input_data, axis=0)

        self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
        self.interpreter.invoke()
        
        output_data = self.interpreter.get_tensor(self.output_details[0]['index'])
        probabilities = output_data[0]
        
        max_prob = np.max(probabilities)
        max_index = np.argmax(probabilities)
        
        predicted_label = self.full_labels[max_index]
        
        return {
            'label': predicted_label,
            'confidence': float(max_prob),
            'probabilities': {self.full_labels[i]: float(probabilities[i]) for i in range(len(self.full_labels))}
        }

