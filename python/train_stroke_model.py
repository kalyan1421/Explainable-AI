import pandas as pd
import numpy as np
import tensorflow as tf
import json
import os
from sklearn.model_selection import train_test_split, StratifiedKFold
from sklearn.preprocessing import StandardScaler, RobustScaler
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score, roc_curve
from imblearn.over_sampling import SMOTE
from imblearn.combine import SMOTETomek
import matplotlib.pyplot as plt
import seaborn as sns
import joblib
from datetime import datetime

# Set random seeds for reproducibility
np.random.seed(42)
tf.random.set_seed(42)

# Create directories
os.makedirs('assets', exist_ok=True)
os.makedirs('models', exist_ok=True)
os.makedirs('reports', exist_ok=True)
os.makedirs('plots', exist_ok=True)

def analyze_dataset(df, required_features, target_col):
    """Perform comprehensive data analysis"""
    print("\n" + "="*60)
    print("📊 DATASET ANALYSIS")
    print("="*60)
    
    # Basic info
    print(f"\n📁 Dataset Shape: {df.shape}")
    print(f"   Rows: {df.shape[0]:,} | Columns: {df.shape[1]}")
    
    # Missing values
    print("\n🔍 Missing Values:")
    missing = df[required_features + [target_col]].isnull().sum()
    for col, count in missing.items():
        if count > 0:
            pct = (count / len(df)) * 100
            print(f"   {col}: {count:,} ({pct:.2f}%)")
    
    # Target distribution
    print(f"\n🎯 Target Distribution ({target_col}):")
    target_counts = df[target_col].value_counts()
    for val, count in target_counts.items():
        pct = (count / len(df)) * 100
        label = "Stroke" if val == 1 else "No Stroke"
        print(f"   {label} ({val}): {count:,} ({pct:.2f}%)")
    
    # Feature statistics
    print("\n📈 Feature Statistics:")
    stats = df[required_features].describe()
    print(stats)
    
    # Check for outliers using IQR method
    print("\n⚠️  Outlier Detection (IQR Method):")
    for col in required_features:
        Q1 = df[col].quantile(0.25)
        Q3 = df[col].quantile(0.75)
        IQR = Q3 - Q1
        outliers = ((df[col] < (Q1 - 1.5 * IQR)) | (df[col] > (Q3 + 1.5 * IQR))).sum()
        if outliers > 0:
            pct = (outliers / len(df)) * 100
            print(f"   {col}: {outliers:,} outliers ({pct:.2f}%)")
    
    return df

def create_visualizations(df, required_features, target_col):
    """Generate comprehensive visualizations"""
    print("\n" + "="*60)
    print("📊 GENERATING VISUALIZATIONS")
    print("="*60)
    
    # 1. Feature distributions
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    fig.suptitle('Feature Distributions', fontsize=16, fontweight='bold')
    
    for idx, feature in enumerate(required_features):
        ax = axes[idx // 3, idx % 3]
        ax.hist(df[feature].dropna(), bins=30, edgecolor='black', alpha=0.7)
        ax.set_title(feature.replace('_', ' ').title())
        ax.set_xlabel('Value')
        ax.set_ylabel('Frequency')
        ax.grid(True, alpha=0.3)
    
    # Remove empty subplot
    fig.delaxes(axes[1, 2])
    plt.tight_layout()
    plt.savefig('plots/feature_distributions.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: plots/feature_distributions.png")
    plt.close()
    
    # 2. Correlation heatmap
    plt.figure(figsize=(10, 8))
    correlation = df[required_features + [target_col]].corr()
    sns.heatmap(correlation, annot=True, fmt='.2f', cmap='coolwarm', 
                center=0, square=True, linewidths=1)
    plt.title('Feature Correlation Matrix', fontsize=16, fontweight='bold')
    plt.tight_layout()
    plt.savefig('plots/correlation_matrix.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: plots/correlation_matrix.png")
    plt.close()
    
    # 3. Feature distributions by target
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    fig.suptitle('Feature Distributions by Stroke Status', fontsize=16, fontweight='bold')
    
    for idx, feature in enumerate(required_features):
        ax = axes[idx // 3, idx % 3]
        df[df[target_col] == 0][feature].hist(ax=ax, bins=20, alpha=0.6, 
                                               label='No Stroke', color='green')
        df[df[target_col] == 1][feature].hist(ax=ax, bins=20, alpha=0.6, 
                                               label='Stroke', color='red')
        ax.set_title(feature.replace('_', ' ').title())
        ax.set_xlabel('Value')
        ax.set_ylabel('Frequency')
        ax.legend()
        ax.grid(True, alpha=0.3)
    
    fig.delaxes(axes[1, 2])
    plt.tight_layout()
    plt.savefig('plots/feature_by_target.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: plots/feature_by_target.png")
    plt.close()

def clean_data(df, required_features, target_col):
    """Clean and preprocess the dataset"""
    print("\n" + "="*60)
    print("🧹 DATA CLEANING")
    print("="*60)
    
    initial_rows = len(df)
    
    # Filter to required columns
    df = df[required_features + [target_col]].copy()
    
    # Handle missing BMI values
    if df['bmi'].isnull().sum() > 0:
        missing_count = df['bmi'].isnull().sum()
        median_bmi = df['bmi'].median()
        df['bmi'].fillna(median_bmi, inplace=True)
        print(f"✅ Filled {missing_count} missing BMI values with median: {median_bmi:.2f}")
    
    # Drop remaining NaN values
    df_clean = df.dropna()
    dropped = initial_rows - len(df_clean)
    if dropped > 0:
        print(f"⚠️  Dropped {dropped} rows with missing values")
    
    # Remove extreme outliers - more lenient bounds
    outliers_removed = 0
    
    # Age should be reasonable (0-120)
    mask = (df_clean['age'] >= 0) & (df_clean['age'] <= 120)
    outliers_removed += (~mask).sum()
    df_clean = df_clean[mask]
    
    # BMI should be reasonable (12-60) - adjusted range
    mask = (df_clean['bmi'] >= 12) & (df_clean['bmi'] <= 60)
    outliers_removed += (~mask).sum()
    df_clean = df_clean[mask]
    
    # Glucose should be reasonable (50-400) - adjusted range
    mask = (df_clean['avg_glucose_level'] >= 50) & (df_clean['avg_glucose_level'] <= 400)
    outliers_removed += (~mask).sum()
    df_clean = df_clean[mask]
    
    if outliers_removed > 0:
        print(f"⚠️  Removed {outliers_removed} extreme outliers")
    
    print(f"\n✅ Final Dataset: {len(df_clean):,} rows")
    print(f"   Data retained: {(len(df_clean)/initial_rows)*100:.2f}%")
    
    return df_clean

def engineer_features(X, feature_names):
    """Create additional engineered features"""
    print("\n" + "="*60)
    print("🔧 FEATURE ENGINEERING")
    print("="*60)
    
    X_df = pd.DataFrame(X, columns=feature_names)
    
    # Create interaction features
    X_df['age_glucose'] = X_df['age'] * X_df['avg_glucose_level'] / 100
    X_df['bmi_glucose'] = X_df['bmi'] * X_df['avg_glucose_level'] / 100
    X_df['age_bmi'] = X_df['age'] * X_df['bmi'] / 100
    
    # Risk indicators
    X_df['health_risk'] = X_df['hypertension'] + X_df['heart_disease']
    X_df['age_squared'] = X_df['age'] ** 2
    X_df['bmi_squared'] = X_df['bmi'] ** 2
    
    # Age groups (polynomial features)
    X_df['age_group_risk'] = np.where(X_df['age'] > 60, 2, 
                              np.where(X_df['age'] > 40, 1, 0))
    
    # Glucose risk levels
    X_df['glucose_risk'] = np.where(X_df['avg_glucose_level'] > 200, 2,
                            np.where(X_df['avg_glucose_level'] > 140, 1, 0))
    
    # BMI categories
    X_df['bmi_category'] = np.where(X_df['bmi'] > 30, 2,
                            np.where(X_df['bmi'] > 25, 1, 0))
    
    new_features = list(X_df.columns)
    print(f"✅ Created {len(new_features) - len(feature_names)} new features")
    print(f"   Total features: {len(new_features)}")
    print(f"   New features: {[f for f in new_features if f not in feature_names]}")
    
    return X_df.values, new_features

def build_improved_model(input_shape, learning_rate=0.0005):
    """Build an improved neural network with better architecture"""
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(input_shape,)),
        
        # First block - wider
        tf.keras.layers.Dense(256, kernel_initializer='he_normal'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation('relu'),
        tf.keras.layers.Dropout(0.4),
        
        # Second block
        tf.keras.layers.Dense(128, kernel_initializer='he_normal'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation('relu'),
        tf.keras.layers.Dropout(0.4),
        
        # Third block
        tf.keras.layers.Dense(64, kernel_initializer='he_normal'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation('relu'),
        tf.keras.layers.Dropout(0.3),
        
        # Fourth block
        tf.keras.layers.Dense(32, kernel_initializer='he_normal'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Activation('relu'),
        tf.keras.layers.Dropout(0.2),
        
        # Fifth block
        tf.keras.layers.Dense(16, kernel_initializer='he_normal'),
        tf.keras.layers.Activation('relu'),
        
        # Output layer
        tf.keras.layers.Dense(1, activation='sigmoid')
    ])
    
    # Use Adam with custom learning rate
    optimizer = tf.keras.optimizers.Adam(
        learning_rate=learning_rate,
        beta_1=0.9,
        beta_2=0.999,
        epsilon=1e-07
    )
    
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

def plot_training_history(history):
    """Plot training metrics"""
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    
    # Loss
    axes[0, 0].plot(history.history['loss'], label='Training Loss', linewidth=2)
    axes[0, 0].plot(history.history['val_loss'], label='Validation Loss', linewidth=2)
    axes[0, 0].set_title('Model Loss', fontsize=14, fontweight='bold')
    axes[0, 0].set_xlabel('Epoch')
    axes[0, 0].set_ylabel('Loss')
    axes[0, 0].legend()
    axes[0, 0].grid(True, alpha=0.3)
    
    # Accuracy
    axes[0, 1].plot(history.history['accuracy'], label='Training Accuracy', linewidth=2)
    axes[0, 1].plot(history.history['val_accuracy'], label='Validation Accuracy', linewidth=2)
    axes[0, 1].set_title('Model Accuracy', fontsize=14, fontweight='bold')
    axes[0, 1].set_xlabel('Epoch')
    axes[0, 1].set_ylabel('Accuracy')
    axes[0, 1].legend()
    axes[0, 1].grid(True, alpha=0.3)
    
    # AUC
    axes[1, 0].plot(history.history['auc'], label='Training AUC', linewidth=2)
    axes[1, 0].plot(history.history['val_auc'], label='Validation AUC', linewidth=2)
    axes[1, 0].set_title('Model AUC', fontsize=14, fontweight='bold')
    axes[1, 0].set_xlabel('Epoch')
    axes[1, 0].set_ylabel('AUC')
    axes[1, 0].legend()
    axes[1, 0].grid(True, alpha=0.3)
    
    # Precision & Recall
    axes[1, 1].plot(history.history['precision'], label='Training Precision', linewidth=2)
    axes[1, 1].plot(history.history['val_precision'], label='Validation Precision', linewidth=2)
    axes[1, 1].plot(history.history['recall'], label='Training Recall', linewidth=2)
    axes[1, 1].plot(history.history['val_recall'], label='Validation Recall', linewidth=2)
    axes[1, 1].set_title('Precision & Recall', fontsize=14, fontweight='bold')
    axes[1, 1].set_xlabel('Epoch')
    axes[1, 1].set_ylabel('Score')
    axes[1, 1].legend()
    axes[1, 1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('plots/training_history.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: plots/training_history.png")
    plt.close()

def evaluate_model(model, X_test, y_test, feature_names):
    """Comprehensive model evaluation"""
    print("\n" + "="*60)
    print("📊 MODEL EVALUATION")
    print("="*60)
    
    # Predictions
    y_pred_proba = model.predict(X_test, verbose=0).flatten()
    
    # Find optimal threshold
    fpr, tpr, thresholds = roc_curve(y_test, y_pred_proba)
    optimal_idx = np.argmax(tpr - fpr)
    optimal_threshold = thresholds[optimal_idx]
    
    print(f"\n🎯 Optimal Threshold: {optimal_threshold:.4f} (default: 0.5)")
    
    # Use optimal threshold
    y_pred = (y_pred_proba >= optimal_threshold).astype(int)
    
    # Metrics - unpack all metrics from evaluate
    eval_results = model.evaluate(X_test, y_test, verbose=0)
    loss = eval_results[0]
    accuracy = eval_results[1]
    auc = eval_results[2]
    
    print(f"\n🎯 Overall Metrics:")
    print(f"   Accuracy: {accuracy*100:.2f}%")
    print(f"   AUC-ROC: {auc:.4f}")
    print(f"   Loss: {loss:.4f}")
    
    # Classification Report
    print(f"\n📋 Classification Report (with optimal threshold):")
    print(classification_report(y_test, y_pred, 
                                target_names=['No Stroke', 'Stroke'],
                                digits=4))
    
    # Confusion Matrix
    cm = confusion_matrix(y_test, y_pred)
    plt.figure(figsize=(8, 6))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                xticklabels=['No Stroke', 'Stroke'],
                yticklabels=['No Stroke', 'Stroke'])
    plt.title(f'Confusion Matrix (threshold={optimal_threshold:.3f})', 
              fontsize=16, fontweight='bold')
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.tight_layout()
    plt.savefig('plots/confusion_matrix.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: plots/confusion_matrix.png")
    plt.close()
    
    # ROC Curve
    plt.figure(figsize=(10, 8))
    plt.plot(fpr, tpr, linewidth=3, label=f'ROC Curve (AUC = {auc:.4f})')
    plt.plot([0, 1], [0, 1], 'k--', linewidth=2, label='Random Classifier')
    plt.scatter([fpr[optimal_idx]], [tpr[optimal_idx]], s=200, c='red', 
                marker='o', label=f'Optimal Threshold = {optimal_threshold:.3f}')
    plt.xlim([0.0, 1.0])
    plt.ylim([0.0, 1.05])
    plt.xlabel('False Positive Rate', fontsize=12)
    plt.ylabel('True Positive Rate', fontsize=12)
    plt.title('ROC Curve', fontsize=16, fontweight='bold')
    plt.legend(loc="lower right", fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig('plots/roc_curve.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: plots/roc_curve.png")
    plt.close()
    
    # Feature importance (using permutation - approximation)
    if len(feature_names) <= 15:  # Only for reasonable number of features
        print("\n🔍 Computing Feature Importance...")
        baseline_auc = roc_auc_score(y_test, y_pred_proba)
        importances = []
        
        for i, feature in enumerate(feature_names):
            X_permuted = X_test.copy()
            np.random.shuffle(X_permuted[:, i])
            y_pred_permuted = model.predict(X_permuted, verbose=0).flatten()
            permuted_auc = roc_auc_score(y_test, y_pred_permuted)
            importance = baseline_auc - permuted_auc
            importances.append(importance)
        
        # Plot feature importance
        feature_importance_df = pd.DataFrame({
            'feature': feature_names,
            'importance': importances
        }).sort_values('importance', ascending=True)
        
        plt.figure(figsize=(10, 8))
        plt.barh(range(len(feature_importance_df)), feature_importance_df['importance'])
        plt.yticks(range(len(feature_importance_df)), feature_importance_df['feature'])
        plt.xlabel('Importance (AUC Drop)', fontsize=12)
        plt.title('Feature Importance', fontsize=16, fontweight='bold')
        plt.grid(True, alpha=0.3, axis='x')
        plt.tight_layout()
        plt.savefig('plots/feature_importance.png', dpi=300, bbox_inches='tight')
        print("✅ Saved: plots/feature_importance.png")
        plt.close()
    
    return {
        'accuracy': accuracy,
        'auc': auc,
        'loss': loss,
        'optimal_threshold': optimal_threshold,
        'y_pred': y_pred,
        'y_pred_proba': y_pred_proba
    }

def save_model_artifacts(model, scaler, original_features, all_features, metrics):
    """Save all model artifacts"""
    print("\n" + "="*60)
    print("💾 SAVING MODEL ARTIFACTS")
    print("="*60)
    
    # Save Keras model
    model.save('models/stroke_model.keras')
    print("✅ Saved: models/stroke_model.keras")
    
    # Save scaler parameters for Flutter (only original features)
    scaler_params = {
        "mean": scaler.mean_[:len(original_features)].tolist(),
        "std": scaler.scale_[:len(original_features)].tolist(),
        "feature_names": original_features
    }
    
    with open('assets/stroke_scaler.json', 'w') as f:
        json.dump(scaler_params, f, indent=2)
    print("✅ Saved: assets/stroke_scaler.json")
    
    # Save complete scaler for all features
    scaler_all_params = {
        "mean": scaler.mean_.tolist(),
        "std": scaler.scale_.tolist(),
        "feature_names": all_features
    }
    
    with open('models/scaler_complete.json', 'w') as f:
        json.dump(scaler_all_params, f, indent=2)
    print("✅ Saved: models/scaler_complete.json")
    
    # Save model metadata
    metadata = {
        "model_version": "2.0",
        "training_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "original_features": original_features,
        "engineered_features": [f for f in all_features if f not in original_features],
        "total_features": len(all_features),
        "optimal_threshold": float(metrics['optimal_threshold']),
        "metrics": {
            "accuracy": float(metrics['accuracy']),
            "auc": float(metrics['auc']),
            "loss": float(metrics['loss'])
        },
        "model_architecture": {
            "input_shape": len(all_features),
            "layers": [
                {"type": "Dense", "units": 256, "activation": "relu"},
                {"type": "Dense", "units": 128, "activation": "relu"},
                {"type": "Dense", "units": 64, "activation": "relu"},
                {"type": "Dense", "units": 32, "activation": "relu"},
                {"type": "Dense", "units": 16, "activation": "relu"},
                {"type": "Dense", "units": 1, "activation": "sigmoid"}
            ]
        },
        "training_config": {
            "used_smote": True,
            "used_feature_engineering": True,
            "scaler_type": "StandardScaler"
        }
    }
    
    with open('models/model_metadata.json', 'w') as f:
        json.dump(metadata, f, indent=2)
    print("✅ Saved: models/model_metadata.json")

def train_stroke_model(use_smote=True, use_feature_engineering=True):
    """Main training pipeline with improvements"""
    print("\n" + "="*70)
    print("🚑 STROKE RISK PREDICTION MODEL TRAINING (ENHANCED)")
    print("="*70)
    print(f"📅 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🔧 SMOTE: {'Enabled' if use_smote else 'Disabled'}")
    print(f"🔧 Feature Engineering: {'Enabled' if use_feature_engineering else 'Disabled'}")
    
    # Configuration
    csv_file = 'stroke.csv'
    required_features = ['age', 'hypertension', 'heart_disease', 'avg_glucose_level', 'bmi']
    target_col = 'stroke'
    
    # 1. Load Data
    print("\n" + "="*60)
    print("📂 LOADING DATA")
    print("="*60)
    
    if not os.path.exists(csv_file):
        print(f"❌ Error: '{csv_file}' not found!")
        print(f"   Please download from: https://www.kaggle.com/datasets/fedesoriano/stroke-prediction-dataset")
        return
    
    df = pd.read_csv(csv_file)
    print(f"✅ Loaded: {csv_file}")
    print(f"   Shape: {df.shape}")
    
    # 2. Analyze Dataset
    df = analyze_dataset(df, required_features, target_col)
    
    # 3. Create Visualizations
    create_visualizations(df, required_features, target_col)
    
    # 4. Clean Data
    df_clean = clean_data(df, required_features, target_col)
    
    # 5. Prepare Features and Target
    X = df_clean[required_features].values
    y = df_clean[target_col].values
    
    # 6. Train-Test Split (before SMOTE to avoid data leakage)
    print("\n" + "="*60)
    print("🔀 SPLITTING DATA")
    print("="*60)
    
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    print(f"✅ Training set: {X_train.shape[0]:,} samples")
    print(f"✅ Test set: {X_test.shape[0]:,} samples")
    print(f"   Train stroke rate: {(y_train.sum()/len(y_train))*100:.2f}%")
    print(f"   Test stroke rate: {(y_test.sum()/len(y_test))*100:.2f}%")
    
    # 7. Feature Engineering (before scaling)
    original_features = required_features.copy()
    if use_feature_engineering:
        X_train, all_features = engineer_features(X_train, required_features)
        X_test, _ = engineer_features(X_test, required_features)
    else:
        all_features = required_features
    
    # 8. Apply SMOTE (before scaling for better results)
    if use_smote:
        print("\n" + "="*60)
        print("⚖️  APPLYING SMOTE (Synthetic Minority Oversampling)")
        print("="*60)
        
        print(f"   Before SMOTE:")
        print(f"   - Class 0: {(y_train == 0).sum():,}")
        print(f"   - Class 1: {(y_train == 1).sum():,}")
        
        # Use SMOTETomek for better balance
        smote_tomek = SMOTETomek(random_state=42)
        X_train, y_train = smote_tomek.fit_resample(X_train, y_train)
        
        print(f"   After SMOTE:")
        print(f"   - Class 0: {(y_train == 0).sum():,}")
        print(f"   - Class 1: {(y_train == 1).sum():,}")
        print(f"✅ Training set resampled: {X_train.shape[0]:,} samples")
    
    # 9. Feature Scaling
    print("\n" + "="*60)
    print("⚖️  FEATURE SCALING")
    print("="*60)
    
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    print("✅ Features standardized using StandardScaler")
    
    # 10. Class Weights (still useful even with SMOTE)
    print("\n" + "="*60)
    print("⚖️  CLASS WEIGHTS")
    print("="*60)
    
    class_weights_array = compute_class_weight(
        class_weight='balanced',
        classes=np.unique(y_train),
        y=y_train
    )
    class_weights = dict(enumerate(class_weights_array))
    print(f"✅ Class weights computed:")
    print(f"   Class 0 (No Stroke): {class_weights[0]:.4f}")
    print(f"   Class 1 (Stroke): {class_weights[1]:.4f}")
    
    # 11. Build Model
    print("\n" + "="*60)
    print("🏗️  BUILDING MODEL")
    print("="*60)
    
    model = build_improved_model(input_shape=len(all_features))
    
    print("✅ Model compiled successfully")
    print(f"\n📊 Model Summary:")
    model.summary()
    
    # 12. Train Model
    print("\n" + "="*60)
    print("🏋️  TRAINING MODEL")
    print("="*60)
    
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_auc',
            patience=20,
            restore_best_weights=True,
            mode='max',
            verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=7,
            min_lr=1e-7,
            verbose=1
        ),
        tf.keras.callbacks.ModelCheckpoint(
            'models/best_model.keras',
            monitor='val_auc',
            save_best_only=True,
            mode='max',
            verbose=0
        )
    ]
    
    history = model.fit(
        X_train_scaled, y_train,
        epochs=200,
        batch_size=64,
        validation_split=0.2,
        class_weight=class_weights if not use_smote else None,
        callbacks=callbacks,
        verbose=1
    )
    
    print("\n✅ Training completed!")
    
    # 13. Plot Training History
    plot_training_history(history)
    
    # 14. Evaluate Model
    metrics = evaluate_model(model, X_test_scaled, y_test, all_features)
    
    # 15. Save Everything
    save_model_artifacts(model, scaler, original_features, all_features, metrics)
    
    # Final Summary
    print("\n" + "="*70)
    print("✅ TRAINING COMPLETE!")
    print("="*70)
    print(f"📅 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"\n📊 Final Performance:")
    print(f"   Accuracy: {metrics['accuracy']*100:.2f}%")
    print(f"   AUC-ROC: {metrics['auc']:.4f}")
    print(f"   Optimal Threshold: {metrics['optimal_threshold']:.4f}")
    print(f"\n📁 Generated Files:")
    print(f"   ├── models/stroke_model.keras")
    print(f"   ├── models/best_model.keras")
    print(f"   ├── models/model_metadata.json")
    print(f"   ├── models/scaler_complete.json")
    print(f"   ├── assets/stroke_scaler.json (for Flutter)")
    print(f"   └── plots/ (7 visualization files)")
    print("\n🎉 Model is ready for deployment in your Flutter app!")
    print("="*70)
    
    return model, metrics

if __name__ == "__main__":
    # Run with all improvements enabled
    model, metrics = train_stroke_model(
        use_smote=True,
        use_feature_engineering=True
    )