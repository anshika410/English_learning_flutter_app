import os
import tempfile
import numpy as np
import librosa
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from sklearn.preprocessing import LabelEncoder
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import Conv2D, MaxPooling2D, Flatten, Dense

app = FastAPI(
    title="Accent Classifier API",
    description="Classifies English accents (Indian vs American) from audio",
    version="1.0.0",
)

MODEL_PATH = "cnn_model.h5"
LABELS_PATH = "label_encoder.npy"

# ── Helpers ──────────────────────────────────────────────────────────────────

def generate_tone(freq, duration=3, sr=16000):
    t = np.linspace(0, duration, int(sr * duration), False)
    return 0.5 * np.sin(2 * np.pi * freq * t)


def extract_mfcc(audio, sr=16000):
    mfcc = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=40)
    mfcc = np.pad(mfcc, ((0, 0), (0, max(0, 130 - mfcc.shape[1]))), mode="constant")[:, :130]
    return mfcc


def create_dataset():
    X, y = [], []
    for _ in range(3):
        X.append(extract_mfcc(generate_tone(440)))
        y.append("indian")
    for _ in range(3):
        X.append(extract_mfcc(generate_tone(880)))
        y.append("american")
    return np.array(X), np.array(y)


def train_and_save():
    X, y = create_dataset()
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


# ── Startup ───────────────────────────────────────────────────────────────────

model = None
label_classes = None


@app.on_event("startup")
async def load_model_on_startup():
    global model, label_classes
    if not os.path.exists(MODEL_PATH):
        print("Training model...")
        model, label_classes = train_and_save()
        print("Model trained and saved.")
    else:
        model = load_model(MODEL_PATH)
        label_classes = np.load(LABELS_PATH, allow_pickle=True)
        print("Model loaded from disk.")


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": model is not None}


@app.post("/predict")
async def predict_accent(file: UploadFile = File(...)):
    """
    Upload a WAV audio file and get accent prediction (indian / american).
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")

    suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        audio, sr = librosa.load(tmp_path, sr=16000, mono=True)
        mfcc = extract_mfcc(audio, sr).reshape(1, 40, 130, 1)
        pred = model.predict(mfcc, verbose=0)
        label = label_classes[np.argmax(pred)]
        confidence = round(float(np.max(pred)), 4)
        all_scores = {label_classes[i]: round(float(p), 4) for i, p in enumerate(pred[0])}

        return JSONResponse({
            "accent": label,
            "confidence": confidence,
            "all_scores": all_scores,
        })

    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Audio processing failed: {str(e)}")
    finally:
        os.unlink(tmp_path)
