# AI Services

Python-based AI/ML components for resume optimization and job matching.

## Services

### 1. Resume Generator
- Position-tailored resume optimization
- ATS-friendly formatting
- Quantified achievement enhancement

### 2. Cover Letter Generator
- Personalized cover letter creation
- Company-specific customization
- Professional tone adaptation

### 3. Skill Analyzer
- Skill gap analysis
- Mind map generation
- Learning path recommendations

### 4. Interview Simulator
- Adaptive questioning system
- Behavioral analysis
- Performance scoring

## Technology Stack

- **Python**: 3.11+
- **ML Framework**: PyTorch, Transformers
- **NLP**: Hugging Face, spaCy, NLTK
- **Vector DB**: ChromaDB
- **API Framework**: FastAPI
- **Experiment Tracking**: MLflow, W&B
- **Data Processing**: Pandas, NumPy
- **PDF Processing**: PyPDF2, pdfplumber

## Development Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run specific service
cd resume-generator
python -m src.main

# Run tests
pytest
```

## Model Management

Models are managed through MLflow:
- Local registry: `http://localhost:5000`
- Model versioning and deployment
- A/B testing capabilities

## API Endpoints

Each service exposes REST APIs:
- Resume Generator: `http://localhost:8090/resume`
- Cover Letter: `http://localhost:8091/cover-letter`
- Skill Analyzer: `http://localhost:8092/skills`
- Interview Simulator: `http://localhost:8093/interview`

## Data Processing

- Input validation and sanitization
- Text preprocessing and tokenization
- Feature extraction and embeddings
- Output formatting and validation

## Monitoring

- Health checks: `/health`
- Metrics: `/metrics`
- Model performance: MLflow UI
