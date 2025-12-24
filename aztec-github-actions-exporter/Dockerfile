FROM python:3.11-slim

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set working directory
WORKDIR /app

# Copy project files
COPY pyproject.toml uv.lock ./
COPY exporter.py ./

# Install dependencies using uv sync with the lock file
RUN uv sync --frozen --no-dev

# Set environment variables (these should be provided at runtime)
ENV VM_URL=""
ENV GITHUB_TOKEN=""

# Run the exporter using uv run (which uses the synced environment)
CMD ["uv", "run", "python", "exporter.py"]

