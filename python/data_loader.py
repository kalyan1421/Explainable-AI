from torchvision import datasets, transforms
from torch.utils.data import DataLoader

def get_dataloaders(data_dir, batch_size=16):
    transform = transforms.Compose([
        transforms.Resize((224,224)),
        transforms.Grayscale(num_output_channels=3),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.5]*3, std=[0.5]*3)
    ])

    train_ds = datasets.ImageFolder(f"{data_dir}/train", transform)
    val_ds   = datasets.ImageFolder(f"{data_dir}/val", transform)
    test_ds  = datasets.ImageFolder(f"{data_dir}/test", transform)

    return (
        DataLoader(train_ds, batch_size, shuffle=True),
        DataLoader(val_ds, batch_size),
        DataLoader(test_ds, batch_size)
    )
