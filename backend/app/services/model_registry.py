"""Process-wide model handles with sequential (lazy) loading.

The detector and classifier *wrapper objects* are created at import time, but
neither trained model is loaded here - importing this module (or starting the
server) must stay well inside the 512 MiB memory limit of the free Render
instance.

``POST /api/analyze`` loads exactly one model at a time inside
:data:`inference_lock`: YOLOv8n is loaded, used, and released with garbage
collection *before* MobileNetV2 is loaded, so both sets of weights are never
resident in memory simultaneously. Routes import the instances from this module
so that ``/api/health`` always reports the state of the very same models used
for inference - never a separate copy.
"""

import threading

from app.services.classifier import OnionHealthClassifier
from app.services.detector import OnionDetector

# Serialises the load -> infer -> release sequence across requests so two
# concurrent analyses can never load duplicate copies of the models.
inference_lock = threading.Lock()

detector = OnionDetector()
classifier = OnionHealthClassifier()
