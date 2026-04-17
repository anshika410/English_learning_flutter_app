import os
import tempfile
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import torchaudio
import torch

# SpeechBrain accent classifier
from speechbrain.pretrained import EncoderClassifier

app = FastAPI(
    title="Accent Classifier API",
    description="Classifies English accents (Indian, American, British, etc.) from audio",
    version="1.0.0",
)

# Load model once on startup
MODEL_SOURCE = "Jzuluaga/accent-id-commonaccent_ecapa"
SAVE_DIR = "/tmp/accent_model"

classifier = None


@app.on_event("startup")
async def load_model():
    global classifier
    print("Loading accent classifier model...")
    classifier = EncoderClassifier.from_hparams(
        source=MODEL_SOURCE,
        savedir=SAVE_DIR,
        run_opts={"device": "cpu"},
    )
    print("Model loaded!")


@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": classifier is not None}


@app.post("/predict")
async def predict_accent(file: UploadFile = File(...)):
    """
    Upload a WAV/MP3/OGG audio file and get accent prediction.

    Returns:
    - accent: predicted accent label
    - confidence: confidence score (0-1)
    - all_scores: scores for all accent classes
    """
    if classifier is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")

    # Validate file type
    allowed = {"audio/wav", "audio/wave", "audio/mpeg", "audio/ogg", "audio/webm"}
    if file.content_type and file.content_type not in allowed:
        # Be lenient — just try to process it
        pass

    # Save uploaded file to temp
    suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        # Load audio
        signal, sr = torchaudio.load(tmp_path)

        # Resample to 16kHz if needed
        if sr != 16000:
            resampler = torchaudio.transforms.Resample(sr, 16000)
            signal = resampler(signal)

        # Convert to mono
        if signal.shape[0] > 1:
            signal = signal.mean(dim=0, keepdim=True)

        # Run inference
        out_prob, score, index, label = classifier.classify_batch(signal)

        # Get all class scores
        probs = torch.softmax(out_prob, dim=-1)[0]
        all_scores = {
            classifier.hparams.label_encoder.decode_ndim(i): round(float(p), 4)
            for i, p in enumerate(probs)
        }

        # Sort by score descending
        all_scores = dict(
            sorted(all_scores.items(), key=lambda x: x[1], reverse=True)
        )

        return JSONResponse({
            "accent": label[0],
            "confidence": round(float(score[0]), 4),
            "all_scores": all_scores,
            "audio_info": {
                "duration_seconds": round(signal.shape[1] / 16000, 2),
                "sample_rate": 16000,
            }
        })

    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Audio processing failed: {str(e)}")
    finally:
        os.unlink(tmp_path)


@app.get("/accents")
async def list_accents():
    """List all supported accent classes."""
    if classifier is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")
    labels = classifier.hparams.label_encoder.ind2lab
    return {"accents": list(labels.values())}
