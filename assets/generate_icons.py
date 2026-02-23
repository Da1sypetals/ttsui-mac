#!/usr/bin/env python3
"""Generate all required app icon sizes from source image."""

from PIL import Image

SOURCE = "qwen-tts-icon.png"

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

DEST_DIR = "../ttsui-mac/Assets.xcassets/AppIcon.appiconset"


def main():
    img = Image.open(SOURCE)
    print(f"Loaded {SOURCE}: {img.size}")

    # Ensure RGBA for transparency support
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    for size, filename in SIZES:
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(f"{DEST_DIR}/{filename}")
        print(f"Generated {filename} ({size}x{size})")

    print("\nAll icons generated successfully!")


if __name__ == "__main__":
    main()
