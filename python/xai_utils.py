import tensorflow as tf
import numpy as np
import cv2

def make_gradcam_heatmap(img_array, model, last_conv_layer_name="Conv_1"):
    """
    Generates a Grad-CAM heatmap for a given image and model.
    """
    # 1. Create a model that maps input image -> last conv layer -> output predictions
    grad_model = tf.keras.models.Model(
        [model.inputs], 
        [model.get_layer(last_conv_layer_name).output, model.output]
    )

    # 2. Compute Gradients
    with tf.GradientTape() as tape:
        last_conv_layer_output, preds = grad_model(img_array)
        pred_index = tf.argmax(preds[0])
        class_channel = preds[:, pred_index]

    # Gradient of the output class with regard to the feature map
    grads = tape.gradient(class_channel, last_conv_layer_output)

    # 3. Global Average Pooling of gradients
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))

    # 4. Multiply feature map by "how important this channel is"
    last_conv_layer_output = last_conv_layer_output[0]
    heatmap = last_conv_layer_output @ pooled_grads[..., tf.newaxis]
    heatmap = tf.squeeze(heatmap)

    # 5. Normalize the heatmap
    heatmap = tf.maximum(heatmap, 0) / tf.math.reduce_max(heatmap)
    return heatmap.numpy()

def process_heatmap_overlay(original_img, heatmap):
    """
    Overlays the heatmap on the original image and returns base64.
    """
    # Rescale heatmap to 0-255
    heatmap = np.uint8(255 * heatmap)
    
    # Colorize
    heatmap = cv2.applyColorMap(heatmap, cv2.COLORMAP_JET)
    
    # Resize to match original image (224x224)
    heatmap = cv2.resize(heatmap, (224, 224))
    
    # Superimpose (Original image must be 0-255 uint8)
    superimposed_img = heatmap * 0.4 + original_img
    
    return superimposed_img