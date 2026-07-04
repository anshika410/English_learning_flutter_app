from PIL import Image
import os
import glob
import numpy as np

def make_transparent(img_path):
    print(f"Processing {img_path}")
    im = Image.open(img_path)
    
    frames = []
    try:
        while True:
            # Convert to RGBA
            frame = im.convert("RGBA")
            data = np.array(frame)
            
            # Find the background color (approximate (236, 247, 232))
            r, g, b, a = data.T
            
            # Tolerance for compression artifacts
            tolerance = 15
            bg_r, bg_g, bg_b = 236, 247, 232
            
            bg_areas = (abs(r - bg_r) < tolerance) & (abs(g - bg_g) < tolerance) & (abs(b - bg_b) < tolerance)
            data[..., :-1][bg_areas.T] = (0, 0, 0)
            data[..., -1][bg_areas.T] = 0
            
            frames.append(Image.fromarray(data))
            im.seek(im.tell() + 1)
    except EOFError:
        pass

    if frames:
        frames[0].save(img_path, save_all=True, append_images=frames[1:], duration=im.info.get('duration', 40), loop=0, format='WEBP')

for f in glob.glob('assets/mascot-animations/*.webp'):
    make_transparent(f)

print("Done")
