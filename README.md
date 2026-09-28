# 🧅 ONION DETECT

### AI-Assisted Onion Quality Inspection & Grading

**Smart India Hackathon 2026**  
**Problem Statement ID: SIH26031**  
**Team Mind Flayers3**

> **AI Measures → Human Verifies → Evidence Recorded**

---

## 🚀 Project Overview

**ONION DETECT** is an AI-assisted onion quality inspection platform designed to make batch inspection **faster, more consistent, traceable, and human-controlled**.

The system combines computer vision, deep learning, standards-informed decision support, human verification, and evidence-ready reporting into one inspection workflow.

### End-to-End Workflow

```text
Capture / Upload
       ↓
Image Quality Check
       ↓
YOLOv8n Detection
       ↓
Individual Onion Cropping
       ↓
MobileNetV2 + LiteRT
       ↓
Healthy / Unhealthy + Confidence
       ↓
Standards-Informed Grade Recommendation
       ↓
Human Confirm / Override
       ↓
Verified Inspection Record
       ↓
Evidence-Ready PDF Report
```

---

# 🎯 Problem

Onion quality assessment and grading can vary across procurement and inspection centres because the process depends heavily on manual visual judgement and operating conditions.

This can create:

- Subjective visual assessment
- Inconsistency between inspection points
- Difficulty handling large batches efficiently
- Limited digital traceability
- Disputes when decisions are not supported by structured evidence

ONION DETECT turns conventional visual inspection into a **structured AI-assisted workflow while keeping the inspector as the final authority**.

---

# 💡 Proposed Solution

### 1. Capture
The inspector records inspection details and captures or uploads a batch image.

### 2. Quality Pre-check
The backend performs basic image-quality and visibility checks before inference.

### 3. Detect
**YOLOv8n** identifies and localises individual onions.

### 4. Assess
Each detected onion is processed using **MobileNetV2**, deployed with **LiteRT / TFLite**, to classify visible health as:

- Healthy
- Unhealthy

with a confidence score.

### 5. Recommend
A configurable, **standards-informed grading layer** processes available visual observations and configured criteria to produce recommendations such as:

- Grade A
- Grade B
- URS
- Human Review where applicable

### 6. Verify
The inspector can **Confirm** or **Override** each recommendation.

The original AI observation is preserved separately from the final human decision.

### 7. Record
The verified inspection can be converted into an **evidence-ready PDF report**.

---

# 🏗️ System Architecture

ONION DETECT follows four logical layers:

```text
┌─────────────────────────────────────────────┐
│              INSPECTION LAYER               │
│ Flutter Web • Details • Upload • Results    │
│ Human Verification                           │
└──────────────────────┬──────────────────────┘
                       ↓
┌─────────────────────────────────────────────┐
│            AI INTELLIGENCE LAYER             │
│ OpenCV Quality Check                         │
│        ↓                                     │
│ YOLOv8n Detection                            │
│        ↓                                     │
│ Individual Onion Cropping                    │
│        ↓                                     │
│ MobileNetV2 + LiteRT                         │
│        ↓                                     │
│ Healthy / Unhealthy + Confidence             │
└──────────────────────┬──────────────────────┘
                       ↓
┌─────────────────────────────────────────────┐
│               DECISION LAYER                 │
│ Per-Onion Aggregation                        │
│        ↓                                     │
│ Standards-Informed Recommendation            │
│        ↓                                     │
│ Grade A / Grade B / URS                      │
│        ↓                                     │
│ Human Confirm / Override                     │
└──────────────────────┬──────────────────────┘
                       ↓
┌─────────────────────────────────────────────┐
│             DATA & EVIDENCE LAYER            │
│ Inspection Records • AI Decision             │
│ Human Decision • PDF Evidence                │
└─────────────────────────────────────────────┘
```

### Key architectural principle

```text
AI Prediction
     ↓
Human Review
     ↓
Final Human Decision
     ↓
Evidence
```

This ensures an inspector can disagree with the AI without losing the original AI observation.

---

# 🧠 AI Pipeline

## YOLOv8n — Onion Detection

YOLOv8n detects and localises individual onion bulbs within a batch image.

```text
Batch Image
     ↓
YOLOv8n
     ↓
Onion 1 • Onion 2 • Onion 3 • ... • Onion N
```

The resulting bounding boxes are used to create individual onion crops for downstream classification.

### Documented detector validation

| Metric | Result |
|---|---:|
| Precision | **89.6%** |
| Recall | **95.1%** |
| mAP@50 | **97.0%** |
| mAP@50–95 | **82.9%** |
| Validation Images | **47** |
| Validation Onions | **102** |

These metrics describe the documented external validation set and are not presented as performance on the full dataset.

---

## MobileNetV2 + LiteRT — Visible Health Assessment

Each detected onion is cropped and passed to a MobileNetV2 classifier.

```text
Individual Onion Crop
        ↓
MobileNetV2 + LiteRT
        ↓
Healthy / Unhealthy
        +
Confidence
```

### Documented classifier test results

| Metric | Result |
|---|---:|
| Test Images | **802** |
| Accuracy | **99.38%** |
| Macro F1 | **99.17%** |

The classifier is intended for **visible health assessment from RGB imagery**.

---

# ⚙️ Standards-Informed Decision Support

ONION DETECT does **not** claim to issue official government certification.

Instead, it uses a configurable **standards-informed grading layer**.

```text
AI Observations
      +
Available Visual Evidence
      +
Configured Quality Criteria
      ↓
Grade Recommendation
```

Possible application recommendations include:

**Grade A / Grade B / URS**

The recommendation is subsequently reviewed by the inspector.

> **Important:** These are decision-support recommendations, not official AGMARK certification.

---

# 👤 Human-in-the-Loop Verification

Human verification is a core part of the architecture.

### ✅ CONFIRM
The inspector accepts the AI recommendation.

### ✏️ OVERRIDE
The inspector changes the recommendation based on their inspection.

The system preserves:

| Record | Meaning |
|---|---|
| **AI Recommendation** | What the AI/decision layer produced |
| **Human Decision** | What the inspector selected |
| **Final Verified Result** | Final outcome after human review |

This creates a clear distinction between **AI assistance and human accountability**.

---

# 📄 Evidence-Ready Reporting

After verification, ONION DETECT generates a structured PDF report containing relevant inspection evidence, such as:

- Inspection details
- Batch information
- Individual onion observations
- Detection information
- Health classification
- AI confidence
- Grade recommendation
- Human verification
- Final decision
- Model / inspection metadata
- Disclaimer information

The objective is to turn an AI-assisted prediction into a **recorded inspection event**.

---

# 🖥️ Application Workflow

```text
HOME
  ↓
START INSPECTION
  ↓
INSPECTION DETAILS
  ↓
IMAGE CAPTURE / UPLOAD
  ↓
IMAGE QUALITY CHECK
  ↓
AI PROCESSING
  ↓
YOLOv8n DETECTION
  ↓
MobileNetV2 + LiteRT
  ↓
INSPECTION RESULTS
  ↓
PER-ONION RECOMMENDATIONS
  ↓
HUMAN CONFIRM / OVERRIDE
  ↓
GRADE DISTRIBUTION
  ↓
GENERATE REPORT
  ↓
PDF REPORT
```

---

# 🛠️ Technology Stack

### Frontend
- Flutter
- Flutter Web
- Material UI
- Modular screens, routes, providers, services, models and widgets

### Backend
- Python
- FastAPI
- Uvicorn
- REST API
- Pydantic schemas

### AI / Computer Vision
- OpenCV
- YOLOv8n
- MobileNetV2
- LiteRT / TFLite

### Deployment
- Firebase Hosting — Flutter Web
- Render — FastAPI backend
- GitHub — Source control

---

# 📁 Project Structure

```text
onion/
│
├── backend/
│   ├── app/
│   │   ├── routes/
│   │   │   ├── analysis.py
│   │   │   ├── health.py
│   │   │   └── reports.py
│   │   │
│   │   ├── schemas/
│   │   │   ├── analysis.py
│   │   │   └── report.py
│   │   │
│   │   ├── services/
│   │   │   ├── classifier.py
│   │   │   ├── detector.py
│   │   │   ├── diagnostics.py
│   │   │   ├── model_registry.py
│   │   │   ├── pipeline.py
│   │   │   ├── report_generator.py
│   │   │   └── verification.py
│   │   │
│   │   ├── utils/
│   │   ├── config.py
│   │   └── main.py
│   │
│   ├── models/
│   ├── scripts/
│   │   └── convert_classifier.py
│   ├── tests/
│   ├── .env.example
│   ├── Dockerfile
│   ├── pytest.ini
│   └── requirements.txt
│
├── frontend/
│   ├── assets/
│   ├── lib/
│   │   ├── config/
│   │   ├── core/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── routes/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── theme/
│   │   └── widgets/
│   ├── public/
│   ├── test/
│   ├── web/
│   ├── pubspec.yaml
│   ├── firebase.json
│   └── .firebaserc
│
├── docker-compose.yml
├── .gitignore
├── cmd.txt
└── README.md
```

---

# 🔌 Backend API

### Analyze Image

```http
POST /api/analyze
```

The analysis endpoint accepts an inspection image and returns structured information including:

- Inspection ID
- Detection count
- Individual detections
- Bounding boxes
- Detection confidence
- Health classification
- Health confidence

### Health

```http
GET /api/health
```

Used to check backend/service availability.

### Reports

The backend also provides report functionality for generating the final evidence-ready PDF.

FastAPI interactive documentation:

```text
http://localhost:8000/docs
```

---

# 🚀 Local Setup

## Prerequisites

- Python
- Flutter SDK
- Git

## Clone

```bash
git clone https://github.com/chandu2006-git/Onion_Quality_Assessment.git
cd Onion_Quality_Assessment
```

## Backend

```bash
cd backend
python -m venv .venv
```

### Windows

```powershell
.venv\Scripts
ctivate
```

### Linux / macOS

```bash
source .venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Create local configuration using:

```text
.env.example
```

Start FastAPI:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Frontend

Open another terminal:

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Release build:

```bash
flutter build web --release
```

---

# 🌐 Deployment

### Live Web App

**ONION DETECT**

https://mindflayers3.web.app/

The deployed frontend is a **Flutter Web application**.

### Production Backend

https://onion-quality-render.onrender.com/

### Demo Video

https://youtu.be/g_KsFwDhUZI

### Source Code

https://github.com/chandu2006-git/Onion_Quality_Assessment

---

# 📊 Model Summary

| Component | Technology | Purpose |
|---|---|---|
| Image Quality | OpenCV | Basic image quality / visibility checks |
| Detection | YOLOv8n | Individual onion localisation |
| Crop Processing | Backend pipeline | Per-onion input preparation |
| Classification | MobileNetV2 | Visible health classification |
| Runtime | LiteRT / TFLite | Lightweight classifier deployment |
| Decision Support | Configurable rules | Grade recommendation |
| Verification | Human-in-the-loop | Confirm / Override |
| Reporting | Report service | Evidence-ready PDF |

---

# ⚠️ Responsible AI & Scope

## The system supports

- Individual onion detection
- Visible health classification
- Confidence-aware AI observations
- Standards-informed recommendations
- Human confirmation / override
- Evidence-ready reporting

## The system does NOT claim

- Official AGMARK certification
- Automated government procurement approval
- Reliable internal-rot detection from ordinary RGB images
- Exact physical diameter without calibration
- Direct firmness or moisture measurement without dedicated sensors
- Replacement of qualified human inspection

---

# 🔬 Internal Defect Limitation

Internal rot and hidden defects may not be reliably observable using ordinary RGB imagery.

A dedicated internal-defect solution would require capabilities such as:

- Specialised optical sensing
- Controlled illumination
- Appropriate wavelength configuration
- Calibrated measurement geometry
- A separately validated spectral dataset

Therefore, the current scope is:

> **Visible quality assessment using RGB imagery with mandatory human verification.**

This limitation is intentionally documented as part of the system's responsible-AI design.

---

# 🏛️ Standards & Research Context

The project is informed by research and domain references related to:

- Onion machine vision
- Agricultural computer vision
- AGMARK onion quality standards
- Directorate of Marketing & Inspection
- APEDA
- Department of Consumer Affairs
- Government onion procurement context
- Supply-chain and quality guidance

These sources provide **domain and standards context** for decision support.

ONION DETECT does not claim to provide official certification on behalf of any government authority.

---

# 🔐 Security & Repository Hygiene

Before deployment or public sharing:

- Never commit `.env` files containing secrets.
- Keep API keys and private credentials outside source control.
- Use `.env.example` to document required configuration.
- Do not commit private Firebase credentials.
- Keep trained model artifacts separate when repository/file-size constraints require it.
- Use environment variables for deployment-specific configuration.

---

# 🧪 Testing

Backend:

```bash
cd backend
pytest
```

Frontend:

```bash
cd frontend
flutter test
```

---

# 🧩 Design Philosophy

### 1. AI Assistance, Not Blind Automation
AI handles repetitive visual analysis while the inspector retains decision authority.

### 2. Per-Onion Intelligence
A batch image is converted into individual onion observations.

### 3. Decision Separation
AI recommendations and human decisions remain distinguishable.

### 4. Evidence Over Prediction
The final output is a structured inspection record, not only a model score.

### 5. Honest Scope
The system clearly distinguishes visible RGB assessment from capabilities requiring additional sensors or calibration.

---

# 🌱 Future Scope

Potential future extensions include:

- Native mobile deployment
- Larger and more diverse datasets
- Calibrated physical-size measurement
- Specialised optical sensing for internal defects
- Additional quality attributes
- Multi-centre inspection analytics
- Role-based inspection management
- Verified-data-driven model improvement
- Broader procurement ecosystem integration
- Advanced offline synchronisation

These are future directions and are not represented as current capabilities.

---

# 🏆 Why ONION DETECT?

A conventional computer-vision demo often ends here:

```text
Image
  ↓
AI Model
  ↓
Prediction
```

ONION DETECT turns it into an operational inspection workflow:

```text
Image
  ↓
Quality Check
  ↓
Individual Detection
  ↓
Health Assessment
  ↓
Quality Recommendation
  ↓
Human Verification
  ↓
Final Decision
  ↓
Evidence
```

The goal is not to eliminate human expertise.

It is to make inspection:

> **Faster • More Consistent • More Traceable • More Accountable**

---

# 👥 Team Mind Flayers3

**Smart India Hackathon 2026**  
**Problem Statement ID: SIH26031**

---

# 🔗 Project Links

🌐 **Live Web App**  
https://mindflayers3.web.app/

🎥 **Demo Video**  
https://youtu.be/g_KsFwDhUZI

💻 **Source Code**  
https://github.com/chandu2006-git/Onion_Quality_Assessment

---

# 📜 Disclaimer

ONION DETECT is an **AI-assisted decision-support system** developed for Smart India Hackathon 2026.

AI observations and grade recommendations are subject to human verification.

The system does not represent official AGMARK certification, government procurement approval, or a replacement for qualified physical inspection.

---

<p align="center">
<strong>🧅 ONION DETECT</strong><br><br>
<strong>AI Measures → Human Verifies → Evidence Recorded</strong><br><br>
Built by <strong>Team Mind Flayers3</strong><br>
Smart India Hackathon 2026
</p>

