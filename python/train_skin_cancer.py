import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout, Input
from tensorflow.keras.models import Model
from tensorflow.keras.optimizers import Adam
import os

# --- Configuration ---
IMG_SIZE = (224, 224)
BATCH_SIZE = 32
EPOCHS = 20
DATA_DIR = 'data/processed_skin_cancer'
MODEL_SAVE_PATH = 'models/skin_cancer_model.h5'

# --- 1. Data Augmentation & Loading ---
# MobileNetV2 expects inputs in [-1, 1]. The 'preprocess_input' function handles this.
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input

train_datagen = ImageDataGenerator(
    preprocessing_function=preprocess_input, # Auto-normalizes to [-1, 1]
    rotation_range=20,
    width_shift_range=0.2,
    height_shift_range=0.2,
    shear_range=0.2,
    zoom_range=0.2,
    horizontal_flip=True,
    fill_mode='nearest'
)

val_datagen = ImageDataGenerator(preprocessing_function=preprocess_input)

print("Loading Data...")
train_generator = train_datagen.flow_from_directory(
    os.path.join(DATA_DIR, 'train'),
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='categorical' # 7 Classes
)

val_generator = val_datagen.flow_from_directory(
    os.path.join(DATA_DIR, 'val'),
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='categorical'
)

# Print class indices for Flutter mapping
print("✅ Class Mappings (Use these in Flutter):", train_generator.class_indices)

# --- 2. Model Architecture ---
# Base: MobileNetV2 (Pre-trained on ImageNet)
base_model = MobileNetV2(weights='imagenet', include_top=False, input_shape=(224, 224, 3))

# Explainability Hook: We name the last conv layer to find it easily later if needed
last_conv_layer = base_model.get_layer('out_relu') 

x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dense(128, activation='relu')(x)
x = Dropout(0.4)(x)
# 7 Output classes
predictions = Dense(7, activation='softmax')(x)

model = Model(inputs=base_model.input, outputs=predictions)

# Freeze base model initially
base_model.trainable = False

model.compile(optimizer=Adam(learning_rate=0.001),
              loss='categorical_crossentropy',
              metrics=['accuracy'])

# --- 3. Initial Training ---
print("🚀 Starting Transfer Learning...")
model.fit(
    train_generator,
    epochs=5,
    validation_data=val_generator
)

# --- 4. Fine-Tuning ---
print("🔧 Fine-tuning...")
base_model.trainable = True
# Freeze first 100 layers, train the rest
for layer in base_model.layers[:100]:
    layer.trainable = False

model.compile(optimizer=Adam(learning_rate=1e-5), # Lower learning rate
              loss='categorical_crossentropy',
              metrics=['accuracy'])

model.fit(
    train_generator,
    epochs=15,
    validation_data=val_generator
)

# --- 5. Save Model ---
model.save(MODEL_SAVE_PATH)
print(f"✅ Model saved to {MODEL_SAVE_PATH}")