import pandas as pd
import os
import shutil
from sklearn.model_selection import train_test_split

# --- Configuration ---
CSV_PATH = 'data/HAM10000_metadata.csv'      # Path to metadata CSV
IMAGE_DIR = 'data/HAM10000_images_part_1'    # Folder containing all raw images
OUTPUT_DIR = 'data/processed_skin_cancer'    # Where to create train/val folders

# Read Metadata
df = pd.read_csv(CSV_PATH)
print(f"Loaded metadata. Total rows: {len(df)}")

# Define classes (lesion types)
lesion_types_dict = {
    'nv': 'Melanocytic nevi',
    'mel': 'Melanoma',
    'bkl': 'Benign keratosis-like lesions',
    'bcc': 'Basal cell carcinoma',
    'akiec': 'Actinic keratoses',
    'vasc': 'Vascular lesions',
    'df': 'Dermatofibroma'
}

# Create Train/Val split
y = df['dx']
df_train, df_val = train_test_split(df, test_size=0.2, random_state=42, stratify=y)

def organize_images(dataset_df, subset_name):
    print(f"Organizing {subset_name} data...")
    for index, row in dataset_df.iterrows():
        image_id = row['image_id']
        dx = row['dx']
        
        # Source path (Check if extension is jpg or jpeg)
        src_path = os.path.join(IMAGE_DIR, image_id + '.jpg')
        if not os.path.exists(src_path):
            continue # Skip if image not found

        # Destination path
        dest_folder = os.path.join(OUTPUT_DIR, subset_name, dx)
        os.makedirs(dest_folder, exist_ok=True)
        
        shutil.copy(src_path, os.path.join(dest_folder, image_id + '.jpg'))

# Run organization
organize_images(df_train, 'train')
organize_images(df_val, 'val')

print("✅ Dataset organization complete!")