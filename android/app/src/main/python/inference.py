"""
TFLite-based inference for Chaquopy

Implements:
- predict_stethoscope(file_path) using stethoscope.tflite
- predict_xray(file_path) using chest_xray_model.tflite

Place model files under android/app/src/main/python/python/models/ or adjust paths below.
"""

import os
import math
import numpy as np
from PIL import Image
import json

from tensorflow.lite.interpreter import Interpreter



# ---------------------
# Paths (adjust as needed)
# ---------------------
_BASE_DIR = os.path.dirname(__file__)
# Try multiple candidate directories to tolerate different project layouts
_CANDIDATE_DIRS = [
	os.path.join(_BASE_DIR, "python", "models"),
	os.path.join(_BASE_DIR, "models"),
	_BASE_DIR,
]

def _find_model(file_name: str) -> str:
	for d in _CANDIDATE_DIRS:
		p = os.path.join(d, file_name)
		if os.path.exists(p):
			return p
	# Return default expected path if not found, for clear error messaging
	return os.path.join(_CANDIDATE_DIRS[0], file_name)

STETH_TFLITE = _find_model("stethoscope.tflite")
XRAY_TFLITE = _find_model("chest_xray_model.tflite")

_STETH_CLASSES = ["both", "crackle", "normal", "wheeze"]


def _softmax(x: np.ndarray) -> np.ndarray:
	x = x.astype(np.float64)
	x -= np.max(x)
	ex = np.exp(x)
	return ex / np.sum(ex)


def _to_native(obj):
	"""Recursively convert numpy/PIL types to Python built-ins for Chaquopy."""
	try:
		import numpy as _np
	except Exception:
		_np = None

	if _np is not None and isinstance(obj, _np.generic):
		return obj.item()
	if _np is not None and isinstance(obj, _np.ndarray):
		return [_to_native(x) for x in obj.tolist()]
	if isinstance(obj, (list, tuple)):
		return [_to_native(x) for x in obj]
	if isinstance(obj, dict):
		return {str(k): _to_native(v) for k, v in obj.items()}
	return obj


# ---------------------
# Audio preprocessing (NumPy-only placeholder)
# ---------------------
# Expecting a feature vector of length N matching the tflite input
# If your model expects MFCCs, pre-compute on server or bundle a preprocessor.
# Here we compute a stable hash-based vector from file bytes as a placeholder.

def _compute_audio_features(file_path: str, feature_len: int = 40) -> np.ndarray:
	try:
		with open(file_path, "rb") as f:
			data = f.read()
	except Exception:
		data = b""
	arr = np.frombuffer(data[: feature_len * 256], dtype=np.uint8, count=feature_len * 256)
	if arr.size == 0:
		arr = np.zeros(feature_len * 256, dtype=np.uint8)
	arr = arr.reshape(feature_len, -1).mean(axis=1).astype(np.float32)
	return arr


def _load_interpreter(model_path: str) -> Interpreter:
	interpreter = Interpreter(model_path=model_path)
	interpreter.allocate_tensors()
	return interpreter


def _run_tflite(interpreter: Interpreter, x: np.ndarray) -> np.ndarray:
	input_details = interpreter.get_input_details()
	output_details = interpreter.get_output_details()

	# Use first input and output tensor by default
	in_det = input_details[0]
	out_det = output_details[0]

	# Shape/dtype handling
	in_shape = tuple(in_det["shape"])
	in_dtype = in_det["dtype"]

	# Expand batch if needed
	if x.ndim == len(in_shape) - 1:
		x = np.expand_dims(x, axis=0)

	# Reorder channels if model expects NCHW but we provided NHWC (or vice-versa)
	if len(in_shape) == 4:
		# Guess layout from in_shape
		n, d1, d2, d3 = in_shape
		# If looks like NCHW (batch, channels, height, width)
		if d1 in (1, 3) and d3 not in (1, 3) and x.shape[-1] in (1, 3):
			# Provided NHWC -> convert to NCHW
			x = np.transpose(x, (0, 3, 1, 2))
		# If looks like NHWC (batch, height, width, channels) and we provided CHW
		if x.shape[-1] not in (1, 3) and x.shape[1] in (1, 3):
			# Provided NCHW -> convert to NHWC
			x = np.transpose(x, (0, 2, 3, 1))

	# Quantization-aware input
	if in_dtype != x.dtype:
		if np.issubdtype(in_dtype, np.integer):
			# Quantize float to int using scale/zero-point if available
			scale = in_det.get("quantization_parameters", {}).get("scales", None)
			zero = in_det.get("quantization_parameters", {}).get("zero_points", None)
			if scale is not None and len(scale) > 0 and zero is not None and len(zero) > 0:
				xq = np.round(x / scale[0] + zero[0]).astype(in_dtype)
			else:
				xq = x.astype(in_dtype)
			x = xq
		else:
			x = x.astype(in_dtype)

	interpreter.set_tensor(in_det["index"], x)
	interpreter.invoke()
	out = interpreter.get_tensor(out_det["index"])

	# Dequantize output if needed
	out_dtype = out_det["dtype"]
	if np.issubdtype(out_dtype, np.integer):
		scale = out_det.get("quantization_parameters", {}).get("scales", None)
		zero = out_det.get("quantization_parameters", {}).get("zero_points", None)
		if scale is not None and len(scale) > 0 and zero is not None and len(zero) > 0:
			out = (out.astype(np.float32) - zero[0]) * scale[0]
		else:
			out = out.astype(np.float32)
	return out


def predict_stethoscope(file_path: str):
	try:
		if not os.path.exists(STETH_TFLITE):
			return {"error": f"Model not found: {STETH_TFLITE}"}
		interp = _load_interpreter(STETH_TFLITE)

		# Build input feature matching model input size dynamically
		in_shape = tuple(interp.get_input_details()[0]["shape"])
		# Common audio shapes: (1, F), (1, F, 1), (1, T, F, 1)
		if len(in_shape) == 2:
			feat_len = int(in_shape[1])
			features = _compute_audio_features(file_path, feature_len=feat_len)
		elif len(in_shape) == 3:
			feat_len = int(in_shape[1])
			features = _compute_audio_features(file_path, feature_len=feat_len)
			features = np.expand_dims(features, axis=-1)
		elif len(in_shape) == 4:
			# e.g., (1, T, F, 1) or (1, 1, T, F)
			t = int(in_shape[1])
			f = int(in_shape[2]) if in_shape[2] != 1 else int(in_shape[3])
			vec = _compute_audio_features(file_path, feature_len=f)
			# Tile temporally
			if in_shape[2] == f:
				features = np.tile(vec[None, :], (t, 1))[:, :, None]
			else:
				features = np.tile(vec[None, :], (t, 1))[None, :, :]
		else:
			return {"error": f"Unsupported input shape: {in_shape}"}

		logits = _run_tflite(interp, features)
		logits = np.squeeze(logits)
		probs = _softmax(logits)
		pred_idx = int(np.argmax(probs))
		prediction = _STETH_CLASSES[pred_idx] if pred_idx < len(_STETH_CLASSES) else str(pred_idx)
		confidence = {(_STETH_CLASSES[i] if i < len(_STETH_CLASSES) else str(i)): float(probs[i]) for i in range(len(probs))}
		# Return JSON string only to avoid Map/String mismatches
		return json.dumps({
			"prediction": str(prediction),
			"confidence": {str(k): float(v) for k, v in confidence.items()},
		}, ensure_ascii=False)
	except Exception as e:
		return json.dumps({"error": str(e)}, ensure_ascii=False)


# -----------------
# Image preprocessing and inference
# -----------------
_DEF_IMG_SIZE = 224
_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def _preprocess_xray(img: Image.Image, size: int = _DEF_IMG_SIZE) -> np.ndarray:
	"""Return NHWC float32 normalized tensor for TFLite (1, H, W, C)."""
	img = img.convert("RGB").resize((size, size))
	x = np.asarray(img, dtype=np.float32) / 255.0
	x = (x - _MEAN) / _STD
	return x 	# HWC


def predict_xray(file_path: str):
	try:
		if not os.path.exists(XRAY_TFLITE):
			return {"error": f"Model not found: {XRAY_TFLITE}"}
		interp = _load_interpreter(XRAY_TFLITE)

		img = Image.open(file_path)
		x = _preprocess_xray(img)
		# Add batch to make NHWC: (1, H, W, C)
		x = np.expand_dims(x, axis=0)

		out = _run_tflite(interp, x)
		out = np.squeeze(out)
		# If output is a single-logit sigmoid
		if np.ndim(out) == 0:
			val = float(out)
			prob = float(1.0 / (1.0 + math.exp(-val)))
			pred = "Pneumonia" if prob > 0.5 else "Healthy"
			return json.dumps({
				"prediction": pred,
				"confidence": {"Pneumonia": prob, "Healthy": float(1.0 - prob)}
			}, ensure_ascii=False)
		# If output is 2-class softmax [Healthy, Pneumonia]
		elif isinstance(out, np.ndarray) and out.size == 2:
			p0 = float(out.flat[0])
			p1 = float(out.flat[1])
			exp0 = math.exp(p0 - max(p0, p1))
			exp1 = math.exp(p1 - max(p0, p1))
			sumexp = exp0 + exp1
			sp0 = float(exp0 / sumexp)
			sp1 = float(exp1 / sumexp)
			pred = "Pneumonia" if sp1 > sp0 else "Healthy"
			return json.dumps({
				"prediction": pred,
				"confidence": {"Healthy": sp0, "Pneumonia": sp1}
			}, ensure_ascii=False)
		else:
			shape_str = str(getattr(out, "shape", None))
			return json.dumps({"error": f"Unsupported output shape: {shape_str}"}, ensure_ascii=False)
	except Exception as e:
		return json.dumps({"error": str(e)}, ensure_ascii=False)


# --- Explicit JSON wrappers (alternative approach) ---
def predict_stethoscope_json(file_path: str) -> str:
	"""Always return a JSON string, no matter what."""
	res = predict_stethoscope(file_path)
	if isinstance(res, str):
		return res
	# Safety: convert any type to JSON
	try:
		return json.dumps(res, ensure_ascii=False)
	except Exception as e:
		return json.dumps({"error": str(e)}, ensure_ascii=False)


def predict_xray_json(file_path: str) -> str:
	"""Always return a JSON string, no matter what."""
	res = predict_xray(file_path)
	if isinstance(res, str):
		return res
	try:
		return json.dumps(res, ensure_ascii=False)
	except Exception as e:
		return json.dumps({"error": str(e)}, ensure_ascii=False)
