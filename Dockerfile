# ── Stage 1: Build React Frontend ──────────────────────────────────────────────
FROM node:18-alpine AS frontend-builder
WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm ci

COPY frontend/ ./
RUN npm run build

# ── Stage 2: Python FastAPI Server ────────────────────────────────────────────
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for OpenCV and PyTorch
RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables for minimal memory & headless execution
ENV NO_ALBUMENTATIONS_UPDATE=1 \
    PYTHONUNBUFFERED=1 \
    OMP_NUM_THREADS=1 \
    MKL_NUM_THREADS=1

# Install Python dependencies (CPU-only PyTorch first for 90% smaller download & lower RAM)
COPY requirements.txt .
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir -r requirements.txt

# Copy project source code
COPY . .

# Copy built frontend static bundle from Stage 1
COPY --from=frontend-builder /app/frontend/build ./frontend/build

# Create required directories
RUN mkdir -p uploads outputs weights

CMD ["sh", "-c", "uvicorn backend.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
