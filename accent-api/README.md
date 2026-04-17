# Accent Classifier API

FastAPI service that classifies English accents from audio using the
[Jzuluaga/accent-id-commonaccent_ecapa](https://huggingface.co/Jzuluaga/accent-id-commonaccent_ecapa)
pretrained ECAPA-TDNN model trained on Common Voice.

## Supported Accents
African, Australia, Canada, England, Hong Kong, Indian, Ireland, Malaysia,
New Zealand, Philippines, Scotland, Singapore, South Atlantic, US, Wales

## Run locally

```bash
docker compose up -d
```

API available at `http://localhost:8001`
Docs at `http://localhost:8001/docs`

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/accents` | List all supported accents |
| POST | `/predict` | Upload audio, get accent prediction |

## Example

```bash
curl -X POST http://localhost:8001/predict \
  -F "file=@your_audio.wav"
```

Response:
```json
{
  "accent": "Indian",
  "confidence": 0.87,
  "all_scores": {
    "Indian": 0.87,
    "US": 0.06,
    "England": 0.04,
    ...
  },
  "audio_info": {
    "duration_seconds": 3.2,
    "sample_rate": 16000
  }
}
```

## Compute notes
- Model size: ~80MB (downloaded once, cached in Docker volume)
- Inference time: ~1-2s on CPU (t3.micro), ~200ms on GPU
- RAM usage: ~1.5GB peak during inference
- Recommended: t3.small or higher for production
