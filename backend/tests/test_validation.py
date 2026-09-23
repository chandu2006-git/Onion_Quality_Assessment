"""Upload validation tests (type, size, decodability) and crop/scale helpers."""

import io
import logging

import pytest
from PIL import Image

from app.config import settings
from app.utils.image_utils import (
    ImageValidationError,
    fit_for_inference,
    limit_long_side,
    load_image,
    scale_bbox,
)
from app.utils.validation import validate_upload
from tests.conftest import make_png_bytes

logging.getLogger("app").setLevel(logging.CRITICAL)


def test_accepts_valid_png():
    image = validate_upload("sample.png", "image/png", make_png_bytes())
    assert image.size == (320, 240)
    assert image.mode == "RGB"


def test_accepts_jpeg_and_webp():
    for fmt, name, mime in (("JPEG", "sample.jpg", "image/jpeg"), ("WEBP", "sample.webp", "image/webp")):
        buffer = io.BytesIO()
        Image.new("RGB", (64, 64), (30, 120, 60)).save(buffer, format=fmt)
        assert validate_upload(name, mime, buffer.getvalue()).size == (64, 64)


def test_rejects_unsupported_extension():
    with pytest.raises(ImageValidationError) as error:
        validate_upload("report.pdf", "application/pdf", make_png_bytes())
    assert "Unsupported file type" in str(error.value)


def test_rejects_non_image_payload():
    with pytest.raises(ImageValidationError) as error:
        validate_upload("sample.png", "image/png", b"this is definitely not an image")
    assert "could not be processed" in str(error.value)


def test_rejects_empty_payload():
    with pytest.raises(ImageValidationError):
        validate_upload("sample.png", "image/png", b"")


def test_rejects_oversized_upload():
    oversized = b"\x89PNG\r\n\x1a\n" + b"\x00" * (settings.max_upload_size_bytes + 1)
    with pytest.raises(ImageValidationError) as error:
        validate_upload("sample.png", "image/png", oversized)
    assert "upload limit" in str(error.value)


def test_rejects_corrupted_image_bytes():
    truncated = make_png_bytes()[:40]
    with pytest.raises(ImageValidationError):
        load_image(truncated)


def test_large_images_are_downscaled_without_changing_boxes():
    pytest.importorskip("cv2", reason="OpenCV (part of the ML runtime) is required for resizing.")
    import numpy as np

    array = np.zeros((4000, 2000, 3), dtype="uint8")
    resized, scale = fit_for_inference(array, 1000)
    assert max(resized.shape[:2]) == 1000
    assert 0 < scale < 1

    # A box in the downscaled frame maps back to the original frame.
    # Round-trip the original box (500, 1000) through the resize: the local
    # coordinates are the original ones multiplied by ``scale`` (0.25 here),
    # and ``scale_bbox`` must map them back exactly.
    local = {"x1": 500 * scale, "y1": 1000 * scale, "x2": 1000 * scale, "y2": 1500 * scale}
    box = scale_bbox(local, 1 / scale, 2000, 4000)
    assert 490 <= box["x1"] <= 510
    assert 990 <= box["y1"] <= 1010
    assert box["x2"] > box["x1"] and box["y2"] > box["y1"]
    assert box == {"x1": 500, "y1": 1000, "x2": 1000, "y2": 1500}


def test_scale_bbox_clamps_to_image_bounds():
    box = scale_bbox({"x1": -50, "y1": -20, "x2": 5000, "y2": 5000}, 1.0, 640, 480)
    assert box == {"x1": 0, "y1": 0, "x2": 640, "y2": 480}


def test_small_images_are_not_resized():
    import numpy as np

    array = np.zeros((300, 400, 3), dtype="uint8")
    resized, scale = fit_for_inference(array, 1000)
    assert scale == 1.0
    assert resized.shape == array.shape


def test_evidence_image_long_side_is_capped():
    wide = Image.new("RGB", (4200, 3000), (40, 90, 60))
    limited = limit_long_side(wide, 1920)
    assert limited.size == (1920, 1371)

    small = Image.new("RGB", (640, 480), (40, 90, 60))
    assert limit_long_side(small, 1920).size == (640, 480)
