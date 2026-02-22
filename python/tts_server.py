#!/usr/bin/env python3
"""
TTS HTTP Server for TTSUI-mac

FastAPI-based HTTP server that provides:
- Model load/unload with memory tracking
- TTS generation endpoints for clone, control, and design modes
- Real-time log streaming via Server-Sent Events (SSE)
- Health monitoring

Usage:
    python tts_server.py [--port PORT] [--host HOST]
"""

import os
import sys
import gc
import time
import logging
import threading
from datetime import datetime
from typing import Optional, Dict, List, Any
from dataclasses import dataclass
from enum import Enum
from contextlib import asynccontextmanager

# Set HF endpoint for faster downloads in China
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

import psutil
import numpy as np
import soundfile as sf
from pathlib import Path
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

from mlx_audio.tts.utils import load_model


# =============================================================================
# Logging Setup
# =============================================================================

def setup_logging() -> logging.Logger:
    """Configure logging to stderr for capture by Swift."""
    logger = logging.getLogger("tts_server")
    logger.setLevel(logging.DEBUG)

    # StreamHandler to stderr (captured by Swift)
    handler = logging.StreamHandler(sys.stderr)
    handler.setLevel(logging.DEBUG)
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)

    return logger


logger = setup_logging()


def get_memory_mb() -> float:
    """Get current process RSS memory in MB."""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024)


# =============================================================================
# Model Registry
# =============================================================================

class ModelState(Enum):
    UNLOADED = "unloaded"
    LOADING = "loading"
    LOADED = "loaded"
    UNLOADING = "unloading"
    ERROR = "error"


@dataclass
class ModelInfo:
    model_id: str
    state: ModelState = ModelState.UNLOADED
    memory_before_mb: Optional[float] = None
    memory_after_mb: Optional[float] = None
    memory_delta_mb: Optional[float] = None
    load_time_seconds: Optional[float] = None
    error_message: Optional[str] = None
    model_instance: Any = None


class ModelRegistry:
    """Registry for managing loaded models."""

    # Available models by type
    CLONE_MODELS = [
        "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16",
        "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16",
    ]

    CONTROL_MODELS = [
        "mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-bf16",
        "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16",
    ]

    DESIGN_MODEL = "mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16"

    def __init__(self):
        self._models: Dict[str, ModelInfo] = {}
        self._lock = threading.Lock()

        # Initialize all known models as unloaded
        for model_id in self.CLONE_MODELS + self.CONTROL_MODELS + [self.DESIGN_MODEL]:
            self._models[model_id] = ModelInfo(model_id=model_id)

    def get_model(self, model_id: str) -> Optional[ModelInfo]:
        with self._lock:
            return self._models.get(model_id)

    def get_all_models(self) -> List[ModelInfo]:
        with self._lock:
            return list(self._models.values())

    def load_model(self, model_id: str) -> ModelInfo:
        """Load a model into memory."""
        with self._lock:
            if model_id not in self._models:
                self._models[model_id] = ModelInfo(model_id=model_id)

            info = self._models[model_id]

            # Already loaded or loading
            if info.state == ModelState.LOADED:
                logger.info(f"Model {model_id} already loaded")
                return info

            if info.state == ModelState.LOADING:
                logger.warning(f"Model {model_id} is already loading")
                return info

            # Start loading
            info.state = ModelState.LOADING
            info.error_message = None

        # Release lock during actual loading
        logger.info(f"Loading model: {model_id}")
        memory_before = get_memory_mb()
        logger.debug(f"Memory before load: {memory_before:.1f} MB")

        start_time = time.time()

        try:
            model = load_model(model_id)
            load_time = time.time() - start_time
            memory_after = get_memory_mb()
            memory_delta = memory_after - memory_before

            with self._lock:
                info = self._models[model_id]
                info.state = ModelState.LOADED
                info.model_instance = model
                info.memory_before_mb = memory_before
                info.memory_after_mb = memory_after
                info.memory_delta_mb = memory_delta
                info.load_time_seconds = load_time

            logger.info("Model loaded successfully")
            logger.debug(f"Memory after load: {memory_after:.1f} MB ({memory_delta:+.1f} MB)")
            logger.debug(f"Load time: {load_time:.1f} seconds")

            return info

        except RuntimeError as e:
            error_msg = str(e)
            logger.error(f"Failed to load model {model_id}: {error_msg}")

            with self._lock:
                info = self._models[model_id]
                info.state = ModelState.ERROR
                info.error_message = error_msg

            raise

    def unload_model(self, model_id: str) -> ModelInfo:
        """Unload a model from memory and force garbage collection."""
        with self._lock:
            if model_id not in self._models:
                raise ValueError(f"Unknown model: {model_id}")

            info = self._models[model_id]

            if info.state != ModelState.LOADED:
                logger.info(f"Model {model_id} is not loaded (state: {info.state.value})")
                return info

            info.state = ModelState.UNLOADING

        logger.info(f"Unloading model: {model_id}")
        memory_before = get_memory_mb()
        logger.debug(f"Memory before unload: {memory_before:.1f} MB")

        # Clear model reference
        with self._lock:
            info = self._models[model_id]
            info.model_instance = None

        # Force garbage collection
        gc.collect()

        # Clear MLX cache
        import mlx.core as mx
        mx.clear_cache()
        logger.debug("Cleared MLX cache")

        memory_after = get_memory_mb()
        memory_delta = memory_after - memory_before

        with self._lock:
            info = self._models[model_id]
            info.state = ModelState.UNLOADED
            info.memory_before_mb = memory_before
            info.memory_after_mb = memory_after
            info.memory_delta_mb = memory_delta

        logger.info("Model unloaded successfully")
        logger.debug(f"Memory after unload: {memory_after:.1f} MB ({memory_delta:+.1f} MB)")

        return info


# Global registry instance
registry = ModelRegistry()


# =============================================================================
# API Models
# =============================================================================

class LoadModelRequest(BaseModel):
    model_id: str


class MemoryStats(BaseModel):
    before_mb: Optional[float] = None
    after_mb: Optional[float] = None
    delta_mb: Optional[float] = None


class LoadModelResponse(BaseModel):
    model_id: str
    state: str
    memory: MemoryStats
    load_time_seconds: Optional[float] = None
    error: Optional[str] = None


class UnloadModelResponse(BaseModel):
    model_id: str
    state: str
    memory: MemoryStats
    error: Optional[str] = None


class ModelInfoResponse(BaseModel):
    model_id: str
    state: str
    memory: MemoryStats
    load_time_seconds: Optional[float] = None
    error: Optional[str] = None


class GenerateCloneRequest(BaseModel):
    model_id: str
    text: str
    ref_audio_path: str
    ref_text: Optional[str] = ""
    output_path: str


class GenerateControlRequest(BaseModel):
    model_id: str
    text: str
    speaker: str
    language: str
    instruct: Optional[str] = ""
    output_path: str


class GenerateDesignRequest(BaseModel):
    text: str
    language: str
    instruct: str
    output_path: str


class GenerateResponse(BaseModel):
    output_path: str
    success: bool
    error: Optional[str] = None


# =============================================================================
# FastAPI Application
# =============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    logger.info("TTS HTTP Server starting up...")
    yield
    logger.info("TTS HTTP Server shutting down...")


app = FastAPI(
    title="TTS HTTP Server",
    description="HTTP server for TTS model management and generation",
    version="1.0.0",
    lifespan=lifespan
)


# =============================================================================
# Health Endpoint
# =============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}


# =============================================================================
# Model Management Endpoints
# =============================================================================

@app.get("/models")
async def list_models():
    """List all known models with their states."""
    models = registry.get_all_models()
    return {
        "models": [
            {
                "model_id": m.model_id,
                "state": m.state.value,
                "memory": {
                    "before_mb": m.memory_before_mb,
                    "after_mb": m.memory_after_mb,
                    "delta_mb": m.memory_delta_mb,
                },
                "load_time_seconds": m.load_time_seconds,
                "error": m.error_message,
            }
            for m in models
        ]
    }


@app.post("/models/load", response_model=LoadModelResponse)
async def load_model_endpoint(request: LoadModelRequest):
    """Load a model into memory."""
    try:
        info = registry.load_model(request.model_id)
        return LoadModelResponse(
            model_id=info.model_id,
            state=info.state.value,
            memory=MemoryStats(
                before_mb=info.memory_before_mb,
                after_mb=info.memory_after_mb,
                delta_mb=info.memory_delta_mb,
            ),
            load_time_seconds=info.load_time_seconds,
            error=info.error_message,
        )
    except Exception as e:
        info = registry.get_model(request.model_id)
        return LoadModelResponse(
            model_id=request.model_id,
            state=info.state.value if info else "error",
            memory=MemoryStats(),
            error=str(e),
        )


@app.post("/models/unload", response_model=UnloadModelResponse)
async def unload_model_endpoint(request: LoadModelRequest):
    """Unload a model from memory."""
    try:
        info = registry.unload_model(request.model_id)
        return UnloadModelResponse(
            model_id=info.model_id,
            state=info.state.value,
            memory=MemoryStats(
                before_mb=info.memory_before_mb,
                after_mb=info.memory_after_mb,
                delta_mb=info.memory_delta_mb,
            ),
            error=info.error_message,
        )
    except Exception as e:
        return UnloadModelResponse(
            model_id=request.model_id,
            state="error",
            memory=MemoryStats(),
            error=str(e),
        )


# =============================================================================
# Generation Endpoints
# =============================================================================

def save_audio(audio, sample_rate: int, output_path: str):
    """Save audio numpy array to WAV file."""
    audio_np = np.array(audio)
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    sf.write(output_path, audio_np, sample_rate)


@app.post("/generate/clone", response_model=GenerateResponse)
async def generate_clone(request: GenerateCloneRequest):
    """Generate audio using clone mode."""
    info = registry.get_model(request.model_id)
    if not info or info.state != ModelState.LOADED:
        raise HTTPException(status_code=400, detail=f"Model {request.model_id} not loaded")

    model = info.model_instance
    sample_rate = model.sample_rate

    logger.info("Processing reference audio...")

    kwargs = {
        "text": request.text,
        "ref_audio": request.ref_audio_path,
    }
    if request.ref_text:
        kwargs["ref_text"] = request.ref_text

    logger.info("Generating audio...")
    results = list(model.generate(**kwargs))

    if not results:
        raise RuntimeError("No audio generated")

    logger.info("Saving output...")
    audio = results[0].audio
    save_audio(audio, sample_rate, request.output_path)
    logger.info(f"Generated clone audio: {request.output_path}")

    return GenerateResponse(output_path=request.output_path, success=True)


@app.post("/generate/control", response_model=GenerateResponse)
async def generate_control(request: GenerateControlRequest):
    """Generate audio using control mode."""
    info = registry.get_model(request.model_id)
    if not info or info.state != ModelState.LOADED:
        raise HTTPException(status_code=400, detail=f"Model {request.model_id} not loaded")

    model = info.model_instance
    sample_rate = model.sample_rate

    logger.info("Preparing generation parameters...")

    kwargs = {
        "text": request.text,
        "speaker": request.speaker,
        "language": request.language,
    }
    if request.instruct:
        kwargs["instruct"] = request.instruct

    logger.info("Generating audio...")
    results = list(model.generate_custom_voice(**kwargs))

    if not results:
        raise RuntimeError("No audio generated")

    logger.info("Saving output...")
    audio = results[0].audio
    save_audio(audio, sample_rate, request.output_path)
    logger.info(f"Generated control audio: {request.output_path}")

    return GenerateResponse(output_path=request.output_path, success=True)


@app.post("/generate/design", response_model=GenerateResponse)
async def generate_design(request: GenerateDesignRequest):
    """Generate audio using design mode."""
    info = registry.get_model(registry.DESIGN_MODEL)
    if not info or info.state != ModelState.LOADED:
        raise HTTPException(status_code=400, detail="VoiceDesign model not loaded")

    model = info.model_instance
    sample_rate = model.sample_rate

    logger.info("Preparing voice design parameters...")

    kwargs = {
        "text": request.text,
        "language": request.language,
        "instruct": request.instruct,
    }

    logger.info("Generating audio with custom voice design...")
    results = list(model.generate_voice_design(**kwargs))

    if not results:
        raise RuntimeError("No audio generated")

    logger.info("Saving output...")
    audio = results[0].audio
    save_audio(audio, sample_rate, request.output_path)
    logger.info(f"Generated design audio: {request.output_path}")

    return GenerateResponse(output_path=request.output_path, success=True)


# =============================================================================
# Main Entry Point
# =============================================================================

def main():
    import argparse

    parser = argparse.ArgumentParser(description="TTS HTTP Server")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8765, help="Port to bind to")
    args = parser.parse_args()

    logger.info(f"Starting TTS HTTP Server on {args.host}:{args.port}")

    uvicorn.run(
        app,
        host=args.host,
        port=args.port,
        log_level="warning",  # Suppress uvicorn's own logging, we handle our own
    )


if __name__ == "__main__":
    main()
