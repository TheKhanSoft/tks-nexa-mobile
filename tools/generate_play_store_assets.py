"""
Script to generate Google Play Store graphics for TKS Nexa Attendance:
- 512x512 App Icon
- 1024x500 Feature Graphic (Display Image)
- 1080x2400 High-Res Promotional Screenshots (6 slides)
"""

import os
import glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAIN_DIR = r"C:\Users\Kashif Ahmad Khan\.gemini\antigravity\brain\37a161e9-2328-4c6b-aa53-b0ddcd969316"
OUTPUT_DIR = os.path.join(ROOT_DIR, "play_store_assets")

ICON_DIR = os.path.join(OUTPUT_DIR, "icon")
FEATURE_DIR = os.path.join(OUTPUT_DIR, "feature_graphic")
SCREENSHOTS_DIR = os.path.join(OUTPUT_DIR, "screenshots")

os.makedirs(ICON_DIR, exist_ok=True)
os.makedirs(FEATURE_DIR, exist_ok=True)
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. GENERATE APP ICON (512x512 PNG, 32-bit with alpha)
# -------------------------------------------------------------
def generate_icon():
    print("Generating Google Play App Icon (512x512)...")
    size = 512
    base = Image.new("RGBA", (size, size), (10, 14, 26, 255))

    # Radial cyan-indigo ambient glow
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = size // 2, size // 2
    for r in range(256, 0, -4):
        alpha = int(48 * (1 - r / 256.0) ** 1.5)
        glow_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(6, 182, 212, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(16))
    base = Image.alpha_composite(base, glow)

    # Load authentic logo emblem
    logo_file = os.path.join(ROOT_DIR, "assets", "images", "android-chrome-512x512.png")
    emblem = Image.open(logo_file).convert("RGBA")
    bbox = emblem.getbbox()
    if bbox:
        emblem = emblem.crop(bbox)

    target_dim = 360
    w, h = emblem.size
    ratio = min(target_dim / w, target_dim / h)
    nw, nh = int(w * ratio), int(h * ratio)
    emblem_resized = emblem.resize((nw, nh), Image.Resampling.LANCZOS)

    # Outer luminous shadow
    icon = base.copy()
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px, py = (size - nw) // 2, (size - nh) // 2
    e_alpha = emblem_resized.split()[3]
    s_layer = Image.new("RGBA", (nw, nh), (6, 182, 212, 120))
    s_layer.putalpha(e_alpha)
    shadow.paste(s_layer, (px, py + 2))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))

    icon = Image.alpha_composite(icon, shadow)
    icon.paste(emblem_resized, (px, py), emblem_resized)

    out_path = os.path.join(ICON_DIR, "play_store_icon_512x512.png")
    icon.save(out_path, format="PNG", optimize=True)
    print(f" -> Saved {out_path}")


# -------------------------------------------------------------
# 2. GENERATE FEATURE GRAPHIC (1024x500 PNG & JPG)
# -------------------------------------------------------------
def generate_feature_graphic():
    print("Generating Google Play Feature Graphic (1024x500)...")
    base_pattern = os.path.join(BRAIN_DIR, "feature_graphic_base_*.jpg")
    matches = glob.glob(base_pattern)
    if not matches:
        print(" [!] Missing feature graphic base render.")
        return

    src_im = Image.open(matches[0]).convert("RGB")
    target_w, target_h = 1024, 500

    scale = target_w / float(src_im.size[0])
    new_h = int(src_im.size[1] * scale)
    src_resized = src_im.resize((target_w, new_h), Image.Resampling.LANCZOS)

    top = (new_h - target_h) // 2
    feature_cropped = src_resized.crop((0, top, target_w, top + target_h))

    png_path = os.path.join(FEATURE_DIR, "feature_graphic_1024x500.png")
    jpg_path = os.path.join(FEATURE_DIR, "feature_graphic_1024x500.jpg")

    feature_cropped.save(png_path, format="PNG", optimize=True)
    feature_cropped.save(jpg_path, format="JPEG", quality=95)
    print(f" -> Saved {png_path} & {jpg_path}")


# -------------------------------------------------------------
# 3. GENERATE 6 PHONE PROMOTIONAL SCREENSHOTS (1080x2400)
# -------------------------------------------------------------
def generate_screenshots():
    print("Generating Google Play Phone Screenshots (1080x2400)...")
    slides_config = [
        {
            "filename": "01_face_biometric_verification.png",
            "mockup_pattern": "face_biometric_mockup_*.jpg",
            "pill": "AI BIOMETRIC VERIFICATION",
            "line1": "Instant Face Biometrics",
            "line2": "With Anti-Spoofing AI",
            "sub": "MobileFaceNet live matching with 99%+ trust scoring",
        },
        {
            "filename": "02_gps_geofenced_attendance.png",
            "mockup_pattern": "gps_geofence_mockup_*.jpg",
            "pill": "PRECISION GPS GEOFENCING",
            "line1": "Location-Aware Punch-In",
            "line2": "Guaranteed On-Premise",
            "sub": "Verify authentic employee presence within branch radius",
        },
        {
            "filename": "03_live_shift_dashboard.png",
            "mockup_pattern": "dashboard_mockup_*.jpg",
            "pill": "REAL-TIME SHIFT DASHBOARD",
            "line1": "Live Shift Tracking &",
            "line2": "Workforce Telemetry",
            "sub": "Real-time working hours, shift timings & punch status",
        },
        {
            "filename": "04_attendance_history_telemetry.png",
            "mockup_pattern": "history_mockup_*.jpg",
            "pill": "SMART ATTENDANCE LOGS",
            "line1": "Monthly History &",
            "line2": "Punch Selfie Records",
            "sub": "Audit-ready calendar history with GPS & biometric watermark",
        },
        {
            "filename": "05_leave_and_regularization_requests.png",
            "mockup_pattern": "requests_mockup_*.jpg",
            "pill": "EMPLOYEE SELF-SERVICE",
            "line1": "Seamless Leaves &",
            "line2": "Regularization Requests",
            "sub": "Quick-apply for time-off, duty travel and attendance adjustments",
        },
        {
            "filename": "06_multitenant_enterprise_login.png",
            "mockup_pattern": "enterprise_qr_mockup_*.jpg",
            "pill": "MULTI-TENANT ENTERPRISE",
            "line1": "Multi-Tenant Portal",
            "line2": "Instant QR Setup & Login",
            "sub": "Scan QR badge to connect your organization in seconds",
        },
    ]

    W, H = 1080, 2400
    font_pill = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 24)
    font_title = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 62)
    font_sub = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 28)

    for cfg in slides_config:
        mockup_files = glob.glob(os.path.join(BRAIN_DIR, cfg["mockup_pattern"]))
        if not mockup_files:
            print(f" [!] Missing mockup for {cfg['filename']}")
            continue
        mockup_path = mockup_files[0]

        phone = Image.open(mockup_path).convert("RGB")
        scale = W / float(phone.size[0])
        target_ph = int(phone.size[1] * scale)
        phone_res = phone.resize((W, target_ph), Image.Resampling.LANCZOS)

        py = 520
        cropped_ph = H - py
        phone_cropped = phone_res.crop((0, 0, W, cropped_ph))

        # Canvas composition
        canvas = Image.new("RGB", (W, H), (0, 0, 0))
        top_strip = phone_cropped.crop((0, 0, W, 80))
        top_bg = top_strip.resize((W, py + 100), Image.Resampling.BILINEAR).filter(
            ImageFilter.GaussianBlur(28)
        )

        canvas.paste(top_bg, (0, 0))
        canvas.paste(phone_cropped, (0, py))

        # Top dark gradient overlay for text readability
        top_overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for y in range(py + 100):
            a = int(220 * (1 - (y / float(py + 100)) ** 1.4))
            line = Image.new("RGBA", (W, 1), (5, 10, 24, a))
            top_overlay.paste(line, (0, y))

        canvas_rgba = canvas.convert("RGBA")
        canvas_rgba = Image.alpha_composite(canvas_rgba, top_overlay)

        # 1. Pill badge
        pill_text = cfg["pill"]
        pill_bbox = font_pill.getbbox(pill_text)
        pill_tw = pill_bbox[2] - pill_bbox[0]
        pill_th = pill_bbox[3] - pill_bbox[1]
        pill_w = pill_tw + 60
        pill_h = 52
        pill_x = (W - pill_w) // 2
        pill_y = 110

        pill_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        p_draw = ImageDraw.Draw(pill_layer)
        p_draw.rounded_rectangle(
            [pill_x, pill_y, pill_x + pill_w, pill_y + pill_h],
            radius=26,
            fill=(6, 182, 212, 40),
            outline=(6, 182, 212, 200),
            width=2,
        )
        p_draw.text(
            (pill_x + 30, pill_y + (pill_h - pill_th) // 2 - 3),
            pill_text,
            fill=(56, 189, 248, 255),
            font=font_pill,
        )
        canvas_rgba = Image.alpha_composite(canvas_rgba, pill_layer)

        # 2. Main Title (Two lines)
        draw = ImageDraw.Draw(canvas_rgba)
        b1 = font_title.getbbox(cfg["line1"])
        w1 = b1[2] - b1[0]
        b2 = font_title.getbbox(cfg["line2"])
        w2 = b2[2] - b2[0]

        y_title = 195
        draw.text(
            ((W - w1) // 2, y_title),
            cfg["line1"],
            fill=(255, 255, 255, 255),
            font=font_title,
        )
        draw.text(
            ((W - w2) // 2, y_title + 78),
            cfg["line2"],
            fill=(255, 255, 255, 255),
            font=font_title,
        )

        # 3. Subtitle
        b_sub = font_sub.getbbox(cfg["sub"])
        w_sub = b_sub[2] - b_sub[0]
        draw.text(
            ((W - w_sub) // 2, y_title + 180),
            cfg["sub"],
            fill=(148, 163, 184, 255),
            font=font_sub,
        )

        out_file = os.path.join(SCREENSHOTS_DIR, cfg["filename"])
        canvas_rgba.save(out_file, format="PNG", optimize=True)
        print(f" -> Saved {out_file}")


if __name__ == "__main__":
    generate_icon()
    generate_feature_graphic()
    generate_screenshots()
    print("Done generating all Google Play assets!")
