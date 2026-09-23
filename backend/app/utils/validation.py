"""Upload validation helpers (type, extension, size, decodability)."""

from pathlib import Path
from typing import Optional

from app.config import settings
from app.utils.image_utils import SUPPORTED_EXTENSIONS, ImageValidationError, load_image


def validate_upload(filename: Optional[str], content_type: Optional[str], data: bytes):
    """Validate an uploaded image and return the decoded Pillow image.

    Raises :class:`ImageValidationError` with a user-safe message.
    """
    if not data:
        raise ImageValidationError("The uploaded file is empty.")

    if len(data) > settings.max_upload_size_bytes:
        raise ImageValidationError(
            f"The selected file is larger than the {settings.MAX_UPLOAD_SIZE_MB} MB upload limit."
        )

    if filename:
        suffix = Path(filename).suffix.lower()
        if suffix and suffix not in SUPPORTED_EXTENSIONS:
            raise ImageValidationError(
                "Unsupported file type. Please upload a JPG, JPEG, PNG or WEBP image."
            )

    if content_type and not content_type.lower().startswith("image/"):
        raise ImageValidationError(
            "Unsupported file type. Please upload a JPG, JPEG, PNG or WEBP image."
        )

    return load_image(data)
