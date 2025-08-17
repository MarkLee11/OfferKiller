FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY models/ ./models/
COPY config/ ./config/

# Create non-root user for security
RUN addgroup --system appuser && adduser --system appuser --ingroup appuser
USER appuser:appuser

# Set environment variables
ENV PYTHONPATH=/app/src
ENV TRANSFORMERS_CACHE=/app/cache
ENV HF_HOME=/app/cache

# Create cache directory
RUN mkdir -p /app/cache

# Expose port
EXPOSE 8090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8090/health || exit 1

# Run the application
CMD ["python", "-m", "src.main"]