# ONION DETECT

AI-Assisted Onion Quality Inspection

## Architecture

- Frontend: Flutter Web (Material 3)
- Backend: FastAPI (Python)
- ML: YOLOv8n (detection) + MobileNetV2 (classification)

## Project Structure

```
onion/
├── frontend/           # Flutter Web application
│   └── lib/
│       ├── main.dart
│       ├── routes/
│       ├── screens/
│       ├── providers/
│       ├── services/
│       ├── models/
│       └── theme/
├── backend/            # FastAPI backend
│   └── app/
│       ├── main.py
│       ├── config.py
│       ├── routes/
│       ├── services/
│       ├── schemas/
│       └── utils/
├── backend/models/     # Place model files here
├── docs/
├── docker-compose.yml
└── README.md
```

## Model Placement

Place the trained model files in `backend/models/`:
- `onion_detector_v1.pt`
- `onion_health_mobilenetv2_best.keras`

## Environment Variables

See `backend/.env.example` for configuration. Key variables:
- `MODEL_DETECTOR_PATH`
- `MODEL_HEALTH_CLASSIFIER_PATH`
- `API_HOST`
- `API_PORT`
- `CORS_ORIGINS`
- `MAX_UPLOAD_SIZE_MB`
- `CONFIDENCE_THRESHOLD`

## Running Locally

### Backend

```bash
cd backend
python -m venv .venv
.venv\\Scripts\\activate  # Windows
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## API Endpoints

- `GET /api/health` — Health check with model status
- `POST /api/analyze` — Upload image for analysis (multipart/form-data)
- `POST /api/report/pdf` — Generate PDF report

## Docker

```bash
docker-compose up --build
```

## Deployment

1. Place model files in `backend/models/`
2. Configure environment variables in `backend/.env`
3. Build and run backend
4. Build Flutter Web (`flutter build web`) and deploy to any static host
5. Update `ApiService` base URL for production

## Important Notes

- The application never claims automatic AGMARK certification
- AI observations are subject to human verification
- The PDF preserves both AI observation and human verification status
- No disease-specific diagnosis is provided
- No calibrated diameter measurement is provided