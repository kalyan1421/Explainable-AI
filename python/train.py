import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.models import Model
from tensorflow.keras.optimizers import Adam
import os

# --- Configuration ---
IMG_SIZE = (224, 224)
BATCH_SIZE = 32
EPOCHS = 10
DATA_DIR = '/Users/kalyan/Client project/Explainable AI/python/data/chest_xray' # Ensure this path is correct

# --- 1. Data Preparation ---
# Important: The model expects inputs scaled 0-1 (rescale=1./255)
train_datagen = ImageDataGenerator(
    rescale=1./255,
    rotation_range=15,
    zoom_range=0.2,
    horizontal_flip=True
)

val_datagen = ImageDataGenerator(rescale=1./255)

print("Loading Data...")
train_generator = train_datagen.flow_from_directory(
    os.path.join(DATA_DIR, 'train'),
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='binary'  # 0=Normal, 1=Pneumonia
)

val_generator = val_datagen.flow_from_directory(
    os.path.join(DATA_DIR, 'val'),
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='binary'
)

# --- 2. Model Architecture ---
# MobileNetV2 is great for X-rays. We exclude the top to add our own classifier.
base_model = MobileNetV2(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
base_model.trainable = False  # Freeze base model initially

x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dense(128, activation='relu')(x)
x = Dropout(0.3)(x)
predictions = Dense(1, activation='sigmoid')(x)

model = Model(inputs=base_model.input, outputs=predictions)

model.compile(optimizer=Adam(learning_rate=0.001),
              loss='binary_crossentropy',
              metrics=['accuracy'])

# --- 3. Training ---
print("Starting Training...")
model.fit(
    train_generator,
    epochs=5,  # Quick train for MVP
    validation_data=val_generator
)

# --- 4. Fine-Tuning (Critical for Accuracy) ---
print("Fine-tuning...")
base_model.trainable = True
# Freeze early layers, train only deep layers
for layer in base_model.layers[:-20]:
    layer.trainable = False

model.compile(optimizer=Adam(learning_rate=1e-5),  # Low learning rate
              loss='binary_crossentropy',
              metrics=['accuracy'])

model.fit(
    train_generator,
    epochs=5,
    validation_data=val_generator
)

# --- 5. Save Model ---
# We save in .h5 format which handles custom architectures well
model.save('../models/pneumonia_model.h5')
print("Model saved to ../models/pneumonia_model.h5")