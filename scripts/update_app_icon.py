import os
from PIL import Image

def generate_icons():
    source_path = r"C:\Users\dudha\.gemini\antigravity-ide\brain\82ad18fc-5a30-4fcd-9729-9ec8a701ad43\.user_uploaded\media_1793265529404.jpg"
    base_dir = r"d:\unity"

    if not os.path.exists(source_path):
        raise FileNotFoundError(f"Source image not found: {source_path}")

    # Load source image
    img = Image.open(source_path).convert("RGBA")
    print(f"Loaded source image: {source_path} ({img.size})")

    # 1. Assets
    assets_icon_dir = os.path.join(base_dir, "assets", "icons")
    os.makedirs(assets_icon_dir, exist_ok=True)
    app_icon_png = os.path.join(assets_icon_dir, "app_icon.png")
    img.resize((512, 512), Image.Resampling.LANCZOS).save(app_icon_png, "PNG")
    print(f"Saved: {app_icon_png}")

    # 2. Windows Runner app_icon.ico
    win_res_dir = os.path.join(base_dir, "windows", "runner", "resources")
    os.makedirs(win_res_dir, exist_ok=True)
    win_ico = os.path.join(win_res_dir, "app_icon.ico")
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    img.save(win_ico, format="ICO", sizes=ico_sizes)
    print(f"Saved: {win_ico} (sizes: {ico_sizes})")

    # 3. Android Mipmaps
    android_res_dir = os.path.join(base_dir, "android", "app", "src", "main", "res")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        folder_path = os.path.join(android_res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        target_path = os.path.join(folder_path, "ic_launcher.png")
        img.resize((size, size), Image.Resampling.LANCZOS).save(target_path, "PNG")
        print(f"Saved Android: {target_path} ({size}x{size})")

    # 4. Web Icons
    web_dir = os.path.join(base_dir, "web")
    web_icons_dir = os.path.join(web_dir, "icons")
    os.makedirs(web_icons_dir, exist_ok=True)
    
    img.resize((48, 48), Image.Resampling.LANCZOS).save(os.path.join(web_dir, "favicon.png"), "PNG")
    img.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-192.png"), "PNG")
    img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-512.png"), "PNG")
    img.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), "PNG")
    img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), "PNG")
    print("Saved Web icons (favicon, 192, 512, maskable)")

    # 5. iOS AppIcon
    ios_icon_dir = os.path.join(base_dir, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_icon_dir):
        ios_sizes = {
            "Icon-App-20x20@1x.png": 20,
            "Icon-App-20x20@2x.png": 40,
            "Icon-App-20x20@3x.png": 60,
            "Icon-App-29x29@1x.png": 29,
            "Icon-App-29x29@2x.png": 58,
            "Icon-App-29x29@3x.png": 87,
            "Icon-App-40x40@1x.png": 40,
            "Icon-App-40x40@2x.png": 80,
            "Icon-App-40x40@3x.png": 120,
            "Icon-App-60x60@2x.png": 120,
            "Icon-App-60x60@3x.png": 180,
            "Icon-App-76x76@1x.png": 76,
            "Icon-App-76x76@2x.png": 152,
            "Icon-App-83.5x83.5@2x.png": 167,
            "Icon-App-1024x1024@1x.png": 1024,
        }
        for filename, size in ios_sizes.items():
            out_file = os.path.join(ios_icon_dir, filename)
            img.resize((size, size), Image.Resampling.LANCZOS).save(out_file, "PNG")
        print("Saved iOS AppIcons")

    # 6. macOS AppIcon
    macos_icon_dir = os.path.join(base_dir, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(macos_icon_dir):
        macos_sizes = {
            "app_icon_16.png": 16,
            "app_icon_32.png": 32,
            "app_icon_64.png": 64,
            "app_icon_128.png": 128,
            "app_icon_256.png": 256,
            "app_icon_512.png": 512,
            "app_icon_1024.png": 1024,
        }
        for filename, size in macos_sizes.items():
            out_file = os.path.join(macos_icon_dir, filename)
            img.resize((size, size), Image.Resampling.LANCZOS).save(out_file, "PNG")
        print("Saved macOS AppIcons")

    print("\n[SUCCESS] All platform app icons successfully generated and replaced!")

if __name__ == "__main__":
    generate_icons()
