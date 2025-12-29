import pandas as pd
import numpy as np
import tensorflow as tf
import json
import os
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.utils.class_weight import compute_class_weight
import warnings

warnings.filterwarnings('ignore')

# Ensure output directories exist
os.makedirs('assets', exist_ok=True)
os.makedirs('models', exist_ok=True)

def preprocess_and_encode(df, dataset_name):
    """Enhanced preprocessing with better handling of categorical variables"""
    print(f"\n🔹 Preprocessing {dataset_name}...")
    
    # 1. DROP USELESS COLUMNS
    drop_cols = ['id', 'dataset']
    for col in drop_cols:
        if col in df.columns:
            df = df.drop(col, axis=1)
            print(f"   Dropped column: {col}")

    # 2. HANDLE TEXT COLUMNS (Encoding)
    mappings = {}
    
    for col in df.columns:
        if df[col].dtype == 'object' or df[col].dtype.name == 'category':
            le = LabelEncoder()
            df[col] = le.fit_transform(df[col].astype(str))
            
            mapping_dict = dict(zip(le.classes_, le.transform(le.classes_)))
            mappings[col] = {str(k): int(v) for k, v in mapping_dict.items()}
            print(f"   Encoded '{col}': {mappings[col]}")
    
    # 3. Handle outliers using IQR method
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    for col in numeric_cols:
        Q1 = df[col].quantile(0.25)
        Q3 = df[col].quantile(0.75)
        IQR = Q3 - Q1
        lower_bound = Q1 - 1.5 * IQR
        upper_bound = Q3 + 1.5 * IQR
        df[col] = df[col].clip(lower=lower_bound, upper=upper_bound)
    
    # Save mappings
    if mappings:
        with open(f'assets/{dataset_name.lower()}_mappings.json', 'w') as f:
            json.dump(mappings, f, indent=2)
            
    return df

def create_optimized_model(input_dim, learning_rate=0.001):
    """Create an optimized neural network"""
    
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(input_dim,)),
        
        # First block
        tf.keras.layers.Dense(128, kernel_regularizer=tf.keras.regularizers.l2(0.001)),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation('relu'),
        tf.keras.layers.Dropout(0.3),
        
        # Second block
        tf.keras.layers.Dense(64, kernel_regularizer=tf.keras.regularizers.l2(0.001)),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation('relu'),
        tf.keras.layers.Dropout(0.3),
        
        # Third block
        tf.keras.layers.Dense(32, kernel_regularizer=tf.keras.regularizers.l2(0.001)),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation('relu'),
        tf.keras.layers.Dropout(0.2),
        
        # Output layer
        tf.keras.layers.Dense(1, activation='sigmoid')
    ])
    
    optimizer = tf.keras.optimizers.Adam(learning_rate=learning_rate)
    
    model.compile(
        optimizer=optimizer,
        loss='binary_crossentropy',
        metrics=[
            'accuracy',
            tf.keras.metrics.AUC(name='auc'),
            tf.keras.metrics.Precision(name='precision'),
            tf.keras.metrics.Recall(name='recall')
        ]
    )
    
    return model

def train_model(dataset_name, csv_filename, target_col):
    """Train and save the model"""
    print(f"\n{'='*50}")
    print(f" TRAINING: {dataset_name} Dataset")
    print(f"{'='*50}")

    # 1. Load Data
    try:
        df = pd.read_csv(csv_filename)
        print(f"✅ Loaded {csv_filename} with shape {df.shape}")
    except FileNotFoundError:
        print(f"❌ ERROR: {csv_filename} not found.")
        return None

    # 2. Auto-Detect Target Column
    if target_col not in df.columns:
        alternatives = ['output', 'num', 'Outcome', 'HeartDisease', 'class', 'target']
        for alt in alternatives:
            if alt in df.columns:
                target_col = alt
                break
    
    if target_col not in df.columns:
        print(f"❌ ERROR: Could not find target column '{target_col}'")
        return None

    # 3. Clean & Encode Data
    df = df.dropna()
    df = preprocess_and_encode(df, dataset_name)
    
    X = df.drop(target_col, axis=1)
    y = df[target_col]
    
    # Check class balance
    print(f"\nClass Distribution:")
    print(f"  Class 0: {(y==0).sum()} ({(y==0).sum()/len(y)*100:.1f}%)")
    print(f"  Class 1: {(y==1).sum()} ({(y==1).sum()/len(y)*100:.1f}%)")

    # 4. Split Data with stratification
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # 5. Scaling (Standardization)
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # Save Scaler Params
    scaler_params = {
        "mean": scaler.mean_.tolist(),
        "std": scaler.scale_.tolist(),
        "feature_names": list(X.columns)
    }
    
    with open(f'assets/{dataset_name.lower()}_scaler.json', 'w') as f:
        json.dump(scaler_params, f, indent=2)
    print(f"✅ Saved Normalization Data")

    # 6. Calculate class weights (capped to prevent extreme values)
    class_weights_array = compute_class_weight(
        'balanced',
        classes=np.unique(y_train),
        y=y_train
    )
    
    max_weight = 3.0
    class_weights_array = np.clip(class_weights_array, 0.5, max_weight)
    class_weights = dict(enumerate(class_weights_array))
    print(f"\nClass Weights (capped): {class_weights}")

    # 7. Build Neural Network
    model = create_optimized_model(input_dim=X_train.shape[1])
    
    print(f"\nModel Architecture:")
    model.summary()

    # 8. Training with callbacks
    print("\n⏳ Training Neural Network...")
    
    early_stopping = tf.keras.callbacks.EarlyStopping(
        monitor='val_loss',
        patience=15,
        restore_best_weights=True,
        verbose=1
    )
    
    reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=5,
        min_lr=1e-6,
        verbose=1
    )
    
    history = model.fit(
        X_train_scaled, y_train,
        validation_split=0.2,
        epochs=150,
        batch_size=32,
        class_weight=class_weights,
        callbacks=[early_stopping, reduce_lr],
        verbose=1
    )
    
    # 9. Evaluation
    print("\n📊 Model Evaluation:")
    test_results = model.evaluate(X_test_scaled, y_test, verbose=0)
    metrics_names = model.metrics_names
    
    results_dict = {}
    for name, value in zip(metrics_names, test_results):
        results_dict[name] = value
        if name == 'loss':
            print(f"  Test Loss: {value:.4f}")
        elif name == 'accuracy':
            print(f"  Test Accuracy: {value*100:.2f}%")
        elif 'auc' in name.lower():
            print(f"  Test AUC-ROC: {value:.4f}")
        elif 'precision' in name.lower():
            print(f"  Test Precision: {value:.4f}")
        elif 'recall' in name.lower():
            print(f"  Test Recall: {value:.4f}")
    
    # Calculate F1 Score
    precision_key = next((k for k in results_dict.keys() if 'precision' in k.lower()), None)
    recall_key = next((k for k in results_dict.keys() if 'recall' in k.lower()), None)
    
    if precision_key and recall_key:
        precision = results_dict[precision_key]
        recall = results_dict[recall_key]
        f1_score = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
        print(f"  Test F1-Score: {f1_score:.4f}")
    else:
        precision = recall = f1_score = 0.0

    # 10. Feature Importance
    first_layer_weights = model.layers[0].get_weights()[0]
    feature_importance = np.abs(first_layer_weights).mean(axis=1)
    feature_importance = feature_importance / feature_importance.sum()
    
    importance_dict = {
        feat: float(imp) 
        for feat, imp in zip(X.columns, feature_importance)
    }
    importance_dict = dict(sorted(importance_dict.items(), key=lambda x: x[1], reverse=True))
    
    print(f"\n🎯 Top 5 Most Important Features:")
    for i, (feat, imp) in enumerate(list(importance_dict.items())[:5], 1):
        print(f"  {i}. {feat}: {imp*100:.2f}%")
    
    with open(f'assets/{dataset_name.lower()}_feature_importance.json', 'w') as f:
        json.dump(importance_dict, f, indent=2)

    # 11. Save Keras Model
    model.save(f'models/{dataset_name.lower()}_model.keras')
    print(f"✅ Saved Keras Model: models/{dataset_name.lower()}_model.keras")

    # 12. Save metadata
    metadata = {
        "model_name": dataset_name,
        "input_shape": X_train.shape[1],
        "features": list(X.columns),
        "accuracy": float(results_dict.get('accuracy', 0)),
        "auc": float(results_dict.get('auc', results_dict.get('auc_1', 0))),
        "precision": float(precision),
        "recall": float(recall),
        "f1_score": float(f1_score),
        "training_samples": len(X_train),
        "test_samples": len(X_test),
        "class_distribution": {
            "class_0": int((y==0).sum()),
            "class_1": int((y==1).sum())
        }
    }
    
    with open(f'assets/{dataset_name.lower()}_metadata.json', 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"✅ Saved Model Metadata")
    
    return model

# ==========================================
# EXECUTE TRAINING
# ==========================================

if __name__ == "__main__":
    print("\n" + "="*50)
    print("Clinical Risk Prediction Model Training")
    print("="*50)

    # 1. Heart Disease
    print("\n🫀 Training Heart Disease Model...")
    heart_model = train_model("Heart", "heart.csv", target_col="target")

    print("\n" + "="*50)

    # 2. Diabetes
    print("\n🩸 Training Diabetes Model...")
    diabetes_model = train_model("Diabetes", "diabetes.csv", target_col="Outcome")

    print("\n" + "="*50)
    print("🎉 TRAINING COMPLETE!")
    print("="*50)
    print("\n📁 Next Step: Run 'convert_to_tflite.py' to create TFLite models")