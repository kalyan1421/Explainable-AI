# backend/app/models/ml_models.py
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import shap
import lime
import lime.lime_tabular
import matplotlib.pyplot as plt
import pickle
import warnings
warnings.filterwarnings('ignore')

class ExplainableHealthcareModel:
    """
    Healthcare AI model with built-in explainability
    """
    
    def __init__(self, model_type='random_forest'):
        self.model_type = model_type
        self.model = None
        self.explainer = None
        self.feature_names = None
        self.class_names = None
        
    def train(self, X_train, y_train, feature_names, class_names):
        """
        Train model with data
        """
        self.feature_names = feature_names
        self.class_names = class_names
        
        # Initialize model
        if self.model_type == 'random_forest':
            self.model = RandomForestClassifier(
                n_estimators=100,
                max_depth=10,
                random_state=42,
                n_jobs=-1
            )
        elif self.model_type == 'gradient_boosting':
            self.model = GradientBoostingClassifier(
                n_estimators=100,
                max_depth=5,
                random_state=42
            )
        
        # Train model
        self.model.fit(X_train, y_train)
        
        # Initialize SHAP explainer
        self.explainer = shap.TreeExplainer(self.model)
        
        print(f"Model trained successfully! Type: {self.model_type}")
        
    def predict(self, X):
        """Make prediction"""
        return self.model.predict(X)
    
    def predict_proba(self, X):
        """Get prediction probabilities"""
        return self.model.predict_proba(X)
    
    def explain_with_shap(self, X_instance):
        """
        Generate SHAP explanation for a single instance
        """
        if self.explainer is None:
            raise ValueError("Model not trained yet!")
        
        # Calculate SHAP values
        shap_values = self.explainer.shap_values(X_instance)
        
        # For binary classification
        if len(shap_values) == 2:
            shap_values = shap_values[1]
        
        # Create explanation dictionary
        explanation = {
            'feature_names': self.feature_names,
            'shap_values': shap_values[0].tolist() if len(shap_values.shape) > 1 else shap_values.tolist(),
            'base_value': self.explainer.expected_value[1] if isinstance(self.explainer.expected_value, list) else self.explainer.expected_value,
            'feature_values': X_instance[0].tolist() if len(X_instance.shape) > 1 else X_instance.tolist()
        }
        
        return explanation
    
    def explain_with_lime(self, X_instance, X_train):
        """
        Generate LIME explanation for a single instance
        """
        # Initialize LIME explainer
        lime_explainer = lime.lime_tabular.LimeTabularExplainer(
            X_train,
            feature_names=self.feature_names,
            class_names=self.class_names,
            mode='classification'
        )
        
        # Generate explanation
        exp = lime_explainer.explain_instance(
            X_instance[0] if len(X_instance.shape) > 1 else X_instance,
            self.model.predict_proba,
            num_features=len(self.feature_names)
        )
        
        # Extract feature importance
        feature_importance = dict(exp.as_list())
        
        return {
            'feature_importance': feature_importance,
            'top_features': list(feature_importance.keys())[:5],
            'prediction_proba': exp.predict_proba
        }
    
    def get_feature_importance(self):
        """Get model's feature importance"""
        if hasattr(self.model, 'feature_importances_'):
            importance_dict = dict(zip(
                self.feature_names,
                self.model.feature_importances_
            ))
            return sorted(importance_dict.items(), key=lambda x: x[1], reverse=True)
        return None
    
    def evaluate(self, X_test, y_test):
        """Evaluate model performance"""
        y_pred = self.predict(X_test)
        
        accuracy = accuracy_score(y_test, y_pred)
        report = classification_report(y_test, y_pred, target_names=self.class_names)
        conf_matrix = confusion_matrix(y_test, y_pred)
        
        return {
            'accuracy': accuracy,
            'classification_report': report,
            'confusion_matrix': conf_matrix.tolist()
        }
    
    def save_model(self, filepath):
        """Save trained model"""
        model_data = {
            'model': self.model,
            'feature_names': self.feature_names,
            'class_names': self.class_names,
            'model_type': self.model_type
        }
        with open(filepath, 'wb') as f:
            pickle.dump(model_data, f)
        print(f"Model saved to {filepath}")
    
    def load_model(self, filepath):
        """Load trained model"""
        with open(filepath, 'rb') as f:
            model_data = pickle.load(f)
        
        self.model = model_data['model']
        self.feature_names = model_data['feature_names']
        self.class_names = model_data['class_names']
        self.model_type = model_data['model_type']
        self.explainer = shap.TreeExplainer(self.model)
        
        print(f"Model loaded from {filepath}")

# Example training script
def train_heart_disease_model():
    """
    Example: Train model for heart disease prediction
    """
    # Load dataset (replace with actual data loading)
    # Example features for heart disease
    data = pd.read_csv('data/raw/heart_disease.csv')
    
    # Features
    feature_names = ['age', 'sex', 'chest_pain_type', 'resting_bp', 
                     'cholesterol', 'fasting_blood_sugar', 'resting_ecg',
                     'max_heart_rate', 'exercise_angina', 'oldpeak', 
                     'slope', 'num_vessels', 'thalassemia']
    
    X = data[feature_names].values
    y = data['target'].values
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    # Initialize and train model
    model = ExplainableHealthcareModel(model_type='random_forest')
    model.train(X_train, y_train, feature_names, ['No Disease', 'Disease'])
    
    # Evaluate
    evaluation = model.evaluate(X_test, y_test)
    print(f"Accuracy: {evaluation['accuracy']:.4f}")
    print("\nClassification Report:")
    print(evaluation['classification_report'])
    
    # Test explanation
    sample = X_test[0:1]
    shap_exp = model.explain_with_shap(sample)
    print("\nSHAP Explanation for first test sample:")
    for feat, val in zip(shap_exp['feature_names'], shap_exp['shap_values']):
        print(f"{feat}: {val:.4f}")
    
    # Save model
    model.save_model('data/models/heart_disease_model.pkl')
    
    return model

if __name__ == "__main__":
    # Train example model
    model = train_heart_disease_model()