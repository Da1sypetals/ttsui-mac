#!/usr/bin/env python3
"""Add rounded corners to app icon and generate all required sizes."""

from PIL import Image, ImageDraw

SOURCE = "qwen-tts.jpeg"
OUTPUT = "qwen-tts-icon.png"

# macOS icon corner radius is ~22.5% of the icon size
CORNER_RADIUS_RATIO = 0.3


def add_rounded_corners(img: Image.Image, radius_ratio: float = CORNER_RADIUS_RATIO) -> Image.Image:
    """Add rounded corners to an image."""
    # Convert to RGBA if needed
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    width, height = img.size
    radius = int(min(width, height) * radius_ratio)

    # Create a mask with rounded corners
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)

    # Draw rounded rectangle
    draw.rounded_rectangle([(0, 0), (width, height)], radius=radius, fill=255)

    # Apply mask to alpha channel
    result = img.copy()
    result.putalpha(mask)

    return result


def main():
    # Load original image
    img = Image.open(SOURCE)
    print(f"Loaded {SOURCE}: {img.size}")

    # Add rounded corners
    rounded = add_rounded_corners(img)
    print(f"Added rounded corners (radius ratio: {CORNER_RADIUS_RATIO})")

    # Save rounded version
    rounded.save(OUTPUT)
    print(f"Saved rounded icon to {OUTPUT}")

    # Generate all required sizes
    sizes = [
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

    dest_dir = "../ttsui-mac/Assets.xcassets/AppIcon.appiconset"

    for size, filename in sizes:
        resized = rounded.resize((size, size), Image.Resampling.LANCZOS)
        output_path = f"{dest_dir}/{filename}"
        resized.save(output_path)
        print(f"Generated {filename} ({size}x{size})")

    print("\nAll icons generated successfully!")


if __name__ == "__main__":
    main()
