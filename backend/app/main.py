"""ONION DETECT - FastAPI application entry point.

AI-Assisted Onion Quality Inspection API.

The server starts without loading any ML model. ``POST /api/analyze`` loads the
YOLOv8n detector, releases it, then loads the MobileNetV2 classifier and
releases it again (sequential lazy loading, guarded by a process-wide lock) so
both models are never resident in memory at the same time and peak RSS stays
inside the 512 MiB limit of the free Render instance. ``/api/health`` reports
model-file presence, current in-memory residency and readiness separately;
``/api/analyze`` refuses to run (503) rather than returning fabricated results
when the trained model files are missing or fail to load.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import configure_logging, settings
from app.routes import analysis, health, reports

configure_logging()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(application: FastAPI):
    logger.info("Starting %s v%s", settings.API_TITLE, settings.API_VERSION)
    # Models are deliberately NOT loaded here: weights load lazily, one model
    # at a time, during /api/analyze (see app.services.pipeline).
    yield
    logger.info("Shutting down %s", settings.API_TITLE)


app = FastAPI(
    title=settings.API_TITLE,
    description=settings.API_DESCRIPTION,
    version=settings.API_VERSION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    # Compiled from wildcard CORS_ORIGINS entries (e.g. http://localhost:*) so
    # Flutter Web works on any local development port without opening the API
    # to arbitrary origins. Credentials stay disabled: no "*" origin + cookies.
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    """Keep error payloads uniform and free of internal detail."""
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail, "path": request.url.path})


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    logger.warning("Request validation failed for %s: %s", request.url.path, exc.errors())
    return JSONResponse(
        status_code=422,
        content={
            "detail": "The submitted inspection data is incomplete or invalid.",
            "path": request.url.path,
        },
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    # Full traceback stays in the server log; the client receives a safe message.
    logger.exception("Unhandled error while processing %s", request.url.path)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "The inspection could not be completed. Please try again or contact the system administrator.",
            "path": request.url.path,
        },
    )


app.include_router(health.router, prefix="/api")
app.include_router(analysis.router, prefix="/api")
app.include_router(reports.router, prefix="/api")


@app.get("/", include_in_schema=False)
def root() -> dict:
    return {
        "name": settings.API_TITLE,
        "description": settings.API_DESCRIPTION,
        "version": settings.API_VERSION,
        "docs": "/docs",
        "endpoints": ["/api/health", "/api/models", "/api/analyze", "/api/report"],
    }
