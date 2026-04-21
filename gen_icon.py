#!/usr/bin/env python3
import os
import sys

# Make sure PIL is available
try:
    from PIL import Image, ImageDraw
except ImportError:
    print("PIL not available, creating minimal PNG instead", file=sys.stderr)
    # Create a minimal valid PNG as fallback
    # This is a 1x1 white pixel PNG
    minimal_png = bytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
        0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0x99, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
        0x00, 0x05, 0xFE, 0x02, 0xB6, 0x4E, 0x21, 0x96, 0x5E, 0x00, 0x00, 0x00,
        0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ])
    os.makedirs('assets', exist_ok=True)
    with open('assets/icon.png', 'wb') as f:
        f.write(minimal_png)
    print("Minimal PNG created")
    sys.exit(0)

# Create assets directory
os.makedirs('assets', exist_ok=True)

# Create a simple moon icon
size = 1024
img = Image.new('RGB', (size, size), color=(0x11, 0x11, 0x11))
draw = ImageDraw.Draw(img)

# Draw a white moon
cx, cy = size // 2, size // 2
radius = 350

# Main moon circle
draw.ellipse([(cx-radius, cy-radius), (cx+radius, cy+radius)], fill=(255, 255, 255))

# Crescent effect - cover part of the moon
draw.ellipse([(cx-radius+80, cy-radius), (cx+radius+80, cy+radius)], fill=(0x11, 0x11, 0x11))

img.save('assets/icon.png')
print("Icon created at assets/icon.png")
