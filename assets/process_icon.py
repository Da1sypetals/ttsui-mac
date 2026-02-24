#!/usr/bin/env python3
"""
Process qwen-tts.jpeg:
1. Rescale to 1024x1024
2. Apply mask from example.png (transparency)
3. Save as qwen-tts.icon.png
4. Generate all icon sizes like generate_icons.py

Can be run from either project root or assets/ directory.
"""

from pathlib import Path
from PIL import Image

# Get the directory where this script is located
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent  # Parent of assets/ is project root

# Source and output files (relative to script location)
SOURCE_IMAGE = SCRIPT_DIR / "qwen-tts.jpeg"
MASK_IMAGE = SCRIPT_DIR / "example.png"
OUTPUT_ICON = SCRIPT_DIR / "qwen-tts.icon.png"
DEST_DIR = PROJECT_ROOT / "ttsui-mac" / "Assets.xcassets" / "AppIcon.appiconset"

# Icon sizes to generate (same as generate_icons.py)
SIZES = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

# Target size for the main icon
TARGET_SIZE = (1024, 1024)


def apply_mask(image, mask):
    """Apply mask alpha channel to image."""
    # Ensure both are RGBA
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    if mask.mode != "RGBA":
        mask = mask.convert("RGBA")

    # Resize mask to match image size if needed
    if mask.size != image.size:
        mask = mask.resize(image.size, Image.Resampling.LANCZOS)

    # Extract alpha channel from mask
    mask_alpha = mask.split()[3]  # Alpha channel

    # Apply mask to image
    # Split image into channels
    r, g, b, a = image.split()

    # We use the mask's alpha as the final alpha
    new_alpha = mask_alpha

    # Merge channels back
    result = Image.merge("RGBA", (r, g, b, new_alpha))

    return result


def main():
    # Verify source files exist
    if not SOURCE_IMAGE.exists():
        print(f"Error: Source image not found: {SOURCE_IMAGE}")
        return 1
    if not MASK_IMAGE.exists():
        print(f"Error: Mask image not found: {MASK_IMAGE}")
        return 1
    
    # Create destination directory if needed
    DEST_DIR.mkdir(parents=True, exist_ok=True)

    # Load source image
    print(f"Loading {SOURCE_IMAGE.name}...")
    source = Image.open(SOURCE_IMAGE)
    print(f"  Original size: {source.size}")

    # Load mask image
    print(f"Loading {MASK_IMAGE.name}...")
    mask = Image.open(MASK_IMAGE)
    print(f"  Mask size: {mask.size}")

    # Resize source to target size
    print(f"Resizing source to {TARGET_SIZE[0]}x{TARGET_SIZE[1]}...")
    source_resized = source.resize(TARGET_SIZE, Image.Resampling.LANCZOS)

    # Apply mask
    print("Applying mask...")
    masked_image = apply_mask(source_resized, mask)

    # Save the icon file
    print(f"Saving {OUTPUT_ICON.name}...")
    masked_image.save(OUTPUT_ICON)
    print("  Saved!")

    # Generate all icon sizes
    print(f"\nGenerating icon sizes in {DEST_DIR.relative_to(PROJECT_ROOT)}...")
    for size, filename in SIZES:
        resized = masked_image.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(DEST_DIR / filename)
        print(f"  Generated {filename} ({size}x{size})")

    print("\nAll done!")
    return 0


if __name__ == "__main__":
    exit(main())
