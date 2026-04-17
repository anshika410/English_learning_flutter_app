import os
import tempfile
import numpy as np
import librosa
from fastapi import APIRouter, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from sklearn.preprocessing import LabelEncoder
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import Conv2D, MaxPooling2D, Flatten, Dense

router = APIRouter(prefix="/accent", tags=["accent"])

MODEL_PATH = "accent_model.h5"
LABELS_PATH = "accent_labels.npy"

# ── Model (loaded once at module level) ──────────────────────────────────────

_model = None
_label_classes = None


def _generate_tone(freq, duration=3, sr=16000):
    t = np.linspace(0, duration, int(sr * duration), False)
    return 0.5 * np.sin(2 * np.pi * freq * t)


def _extract_mfcc(audio, sr=16000):
    mfcc = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=40)
    mfcc = np.pad(mfcc, ((0, 0), (0, max(0, 130 - mfcc.shape[1]))), mode="constant")[:, :130]
    return mfcc


def _create_dataset():
    X, y = [], []
    for _ in range(3):
        X.append(_extract_mfcc(_generate_tone(440)))
        y.append("indian")
    for _ in range(3):
        X.append(_extract_mfcc(_generate_tone(880)))
        y.append("american")
    return np.array(X), np.array(y)


def _train_and_save():
    X, y = _create_dataset()
    le = LabelEncoder()
    y_enc = le.fit_transform(y)
    y_cat = to_categorical(y_enc)
    X = X.reshape(-1, 40, 130, 1)

    model = Sequential([
        Conv2D(32, (3, 3), activation="relu", input_shape=(40, 130, 1)),
        MaxPooling2D((2, 2)),
        Conv2D(64, (3, 3), activation="relu"),
        MaxPooling2D((2, 2)),
        Flatten(),
        Dense(128, activation="relu"),
        Dense(len(le.classes_), activation="softmax"),
    ])
    model.compile(optimizer="adam", loss="categorical_crossentropy", metrics=["accuracy"])
    model.fit(X, y_cat, epochs=10, batch_size=2, verbose=0)
    model.save(MODEL_PATH)
    np.save(LABELS_PATH, le.classes_)
    return model, le.classes_


def load_accent_model():
    global _model, _label_classes
    if not os.path.exists(MODEL_PATH):
        print("Accent model not found — training now...")
        _model, _label_classes = _train_and_save()
        print("Accent model trained and saved.")
    else:
        _model = load_model(MODEL_PATH)
        _label_classes = np.load(LABELS_PATH, allow_pickle=True)
        print("Accent model loaded.")


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/predict")
async def predict_accent(file: UploadFile = File(...)):
    """
    Upload a WAV audio file and get accent prediction (indian / american).
    No auth required — open endpoint for POC.
    """
    if _model is None:
        raise HTTPException(status_code=503, detail="Accent model not loaded yet")

    suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        audio, sr = librosa.load(tmp_path, sr=16000, mono=True)
        mfcc = _extract_mfcc(audio, sr).reshape(1, 40, 130, 1)
        pred = _model.predict(mfcc, verbose=0)
        label = _label_classes[np.argmax(pred)]
        confidence = round(float(np.max(pred)), 4)
        all_scores = {_label_classes[i]: round(float(p), 4) for i, p in enumerate(pred[0])}

        return JSONResponse({
            "accent": label,
            "confidence": confidence,
            "all_scores": all_scores,
        })

    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Audio processing failed: {str(e)}")
    finally:
        os.unlink(tmp_path)
