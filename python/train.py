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
DATA_DIR = '../data/chest_xray'  # Ensure dataset is unzipped here

# --- 1. Data Preparation (Augmentation & Loading) ---
# Augmentation helps prevent overfitting on the 5,863 images
train_datagen = ImageDataGenerator(
    rescale=1./255,
    rotation_range=15,
    zoom_range=0.2,
    horizontal_flip=True,
    brightness_range=[0.8, 1.2]
)

test_datagen = ImageDataGenerator(rescale=1./255)

train_generator = train_datagen.flow_from_directory(
    os.path.join(DATA_DIR, 'train'),
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='binary',
    color_mode='rgb'
)

val_generator = test_datagen.flow_from_directory(
    os.path.join(DATA_DIR, 'val'),
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='binary'
)

# --- 2. Model Architecture (Transfer Learning) ---
# We use MobileNetV2 pre-trained on ImageNet for better feature extraction
base_model = MobileNetV2(weights='imagenet', include_top=False, input_shape=(224, 224, 3))

# Freeze base layers to keep pre-trained patterns
base_model.trainable = False

x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dense(128, activation='relu')(x)
x = Dropout(0.3)(x)  # Reduces overfitting
predictions = Dense(1, activation='sigmoid')(x)  # Binary output: Normal (0) vs Pneumonia (1)

model = Model(inputs=base_model.input, outputs=predictions)

# --- 3. Training ---
model.compile(optimizer=Adam(learning_rate=0.0001),
              loss='binary_crossentropy',
              metrics=['accuracy'])

print("Starting Training...")
history = model.fit(
    train_generator,
    epochs=EPOCHS,
    validation_data=val_generator,
    steps_per_epoch=train_generator.samples // BATCH_SIZE,
    validation_steps=val_generator.samples // BATCH_SIZE
)

# --- 4. Fine-Tuning (Optional but recommended for best results) ---
print("Fine-tuning base model...")
base_model.trainable = True
# Fine-tune only the top 20 layers
for layer in base_model.layers[:-20]:
    layer.trainable = False

model.compile(optimizer=Adam(learning_rate=1e-5),  # Lower learning rate
              loss='binary_crossentropy',
              metrics=['accuracy'])

model.fit(
    train_generator,
    epochs=5,
    validation_data=val_generator
)

# --- 5. Save Model ---
model.save('../models/pneumonia_model_mvp.h5')
print("Model saved as pneumonia_model_mvp.h5")