"""Image loading, validation, cropping and annotation helpers.

``Pillow`` is used for decoding/encoding (portable in containers/serverless),
while ``OpenCV`` is used for the array operations the pipeline needs. Both are
imported lazily so the API can boot without the ML stack installed.
"""

import io
import logging
from typing import Dict, Iterable, List, Tuple

from PIL import Image, ImageOps, UnidentifiedImageError

logger = logging.getLogger(__name__)

SUPPORTED_FORMATS = ("JPEG", "PNG", "WEBP")
SUPPORTED_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")

# Overlay palette (RGB) - restrained, matching the product colour system.
COLOR_BOX_HEALTHY = (46, 107, 74)
COLOR_BOX_UNHEALTHY = (176, 58, 58)


class ImageValidationError(ValueError):
    """Raised when an uploaded file cannot be accepted or decoded."""


def load_image(data: bytes) -> Image.Image:
    """Decode uploaded bytes into an upright RGB image."""
    if not data:
        raise ImageValidationError("The uploaded file is empty.")
    try:
        probe = Image.open(io.BytesIO(data))
        probe.verify()
        # verify() leaves the file object unusable, so reopen for real work.
        image = Image.open(io.BytesIO(data))
        image.load()
    except UnidentifiedImageError as exc:
        raise ImageValidationError(
            "The selected file could not be processed. Please upload a valid JPG, PNG or WEBP image."
        ) from exc
    except Exception as exc:
        raise ImageValidationError(
            "The selected file could not be processed. The image appears to be corrupted."
        ) from exc

    if image.format and image.format.upper() not in SUPPORTED_FORMATS:
        raise ImageValidationError(
            f"Unsupported image format '{image.format}'. Supported formats: JPG, JPEG, PNG, WEBP."
        )
    # Respect EXIF orientation (phone cameras) without distorting the image.
    image = ImageOps.exif_transpose(image)
    if image.mode != "RGB":
        image = image.convert("RGB")
    return image


def pil_to_cv2(image: Image.Image):
    import numpy as np

    return np.asarray(image.convert("RGB"))[:, :, ::-1].copy()


def cv2_to_pil(array) -> Image.Image:
    import cv2

    return Image.fromarray(cv2.cvtColor(array, cv2.COLOR_BGR2RGB))


def fit_for_inference(array, max_side: int):
    """Downscale for detection when needed. Returns (array, scale).

    The resize is a no-op for images that already fit, and in that case OpenCV is
    never imported.
    """
    height, width = array.shape[:2]
    longest = max(height, width)
    if longest <= max_side:
        return array, 1.0
    import cv2

    scale = max_side / float(longest)
    resized = cv2.resize(
        array,
        (max(1, int(round(width * scale))), max(1, int(round(height * scale)))),
        interpolation=cv2.INTER_AREA,
    )
    return resized, scale


def scale_bbox(bbox: Dict[str, float], factor: float, width: int, height: int) -> Dict[str, int]:
    """Map a bounding box back to original image space and clamp it."""
    x1 = max(0, min(int(round(bbox["x1"] * factor)), width - 1))
    y1 = max(0, min(int(round(bbox["y1"] * factor)), height - 1))
    x2 = max(x1 + 1, min(int(round(bbox["x2"] * factor)), width))
    y2 = max(y1 + 1, min(int(round(bbox["y2"] * factor)), height))
    return {"x1": x1, "y1": y1, "x2": x2, "y2": y2}


def draw_annotations(array, detections: Iterable[Dict]):
    """Draw bounding boxes, bulb numbers, health state and health confidence."""
    import cv2

    canvas = array.copy()
    height, width = canvas.shape[:2]
    thickness = max(2, int(round(min(height, width) / 400)))
    font_scale = max(0.5, min(height, width) / 900.0)
    text_thickness = max(1, thickness - 1)

    for detection in detections:
        bbox = detection["bbox"]
        healthy = str(detection["health"]).lower() == "healthy"
        color = COLOR_BOX_HEALTHY if healthy else COLOR_BOX_UNHEALTHY
        label = f"#{detection['id']:02d} {detection['health']} {detection['health_confidence'] * 100:.1f}%"

        cv2.rectangle(canvas, (bbox["x1"], bbox["y1"]), (bbox["x2"], bbox["y2"]), color, thickness)
        (text_width, text_height), baseline = cv2.getTextSize(
            label, cv2.FONT_HERSHEY_SIMPLEX, font_scale, text_thickness
        )
        label_top = bbox["y1"] - text_height - baseline - 6
        if label_top < 0:
            label_top = min(max(0, height - text_height - baseline - 6), bbox["y1"] + thickness + 2)
        label_left = max(0, min(bbox["x1"], max(0, width - text_width - 10)))
        cv2.rectangle(
            canvas,
            (label_left, label_top),
            (label_left + text_width + 10, label_top + text_height + baseline + 6),
            color,
            -1,
        )
        cv2.putText(
            canvas,
            label,
            (label_left + 5, label_top + text_height + 2),
            cv2.FONT_HERSHEY_SIMPLEX,
            font_scale,
            (255, 255, 255),
            text_thickness,
            cv2.LINE_AA,
        )
    return canvas


def centre_region(array, detections: List[Dict], padding: float = 0.08) -> Tuple[int, int, int, int]:
    """Region covering all detections; used for the PDF evidence thumbnail."""
    height, width = array.shape[:2]
    if not detections:
        return 0, 0, width, height
    xs = [d["bbox"]["x1"] for d in detections] + [d["bbox"]["x2"] for d in detections]
    ys = [d["bbox"]["y1"] for d in detections] + [d["bbox"]["y2"] for d in detections]
    pad_x = int((max(xs) - min(xs)) * padding) + 8
    pad_y = int((max(ys) - min(ys)) * padding) + 8
    return (
        int(max(0, min(xs) - pad_x)),
        int(max(0, min(ys) - pad_y)),
        int(min(width, max(xs) + pad_x)),
        int(min(height, max(ys) + pad_y)),
    )

def crop_bbox(array, bbox: Dict[str, int]):
    return array[bbox["y1"]: bbox["y2"], bbox["x1"]: bbox["x2"]]


def encode_image_to_bytes(image: Image.Image, fmt: str = "JPEG", quality: int = 88) -> bytes:
    buffer = io.BytesIO()
    if fmt.upper() == "JPEG":
        image.convert("RGB").save(buffer, format="JPEG", quality=quality, optimize=True)
    else:
        image.save(buffer, format=fmt.upper())
    return buffer.getvalue()


def limit_long_side(image: Image.Image, max_side: int) -> Image.Image:
    """Cap the long side of an image, preserving its aspect ratio.

    Used for the annotated evidence image so a very large upload cannot produce an
    oversized JSON payload or an oversized PDF page. Bounding boxes are drawn
    before this step, therefore the proportions stay correct.
    """
    width, height = image.size
    longest = max(width, height)
    if longest <= max_side:
        return image
    scale = max_side / float(longest)
    return image.resize(
        (max(1, int(round(width * scale))), max(1, int(round(height * scale)))),
        Image.LANCZOS,
    )
