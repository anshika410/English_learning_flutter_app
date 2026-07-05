import os
from google import genai
from google.genai import types
from PIL import Image

client = genai.Client()

def describe_image(image_path):
    print(f"\n--- Describing {image_path} ---")
    img = Image.open(image_path)
    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=[img, "Describe this UI design in high detail. What colors, fonts, layout, and components are used? This is a login screen reference."],
    )
    print(response.text)

describe_image('/Users/mahendra/.gemini/antigravity/brain/0daa36b6-4fa7-4a2c-af44-e9df2ae2b768/media__1783169838186.jpg')
describe_image('/Users/mahendra/.gemini/antigravity/brain/0daa36b6-4fa7-4a2c-af44-e9df2ae2b768/media__1783169848736.jpg')
describe_image('/Users/mahendra/.gemini/antigravity/brain/0daa36b6-4fa7-4a2c-af44-e9df2ae2b768/media__1783169855587.jpg')
