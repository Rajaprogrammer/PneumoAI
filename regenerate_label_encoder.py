import pickle
from sklearn.preprocessing import LabelEncoder
import json

# Load label mapping
with open("models/label_mapping.json", "r") as f:
    label_map = json.load(f)

# Reverse map: 0 -> both, 1 -> crackle, etc.
labels = [label for label, _ in sorted(label_map.items(), key=lambda x: x[1])]

# Fit new encoder
le = LabelEncoder()
le.fit(labels)

# Save the encoder
with open("models/label_encoder.pkl", "wb") as f:
    pickle.dump(le, f)

print("✅ label_encoder.pkl regenerated successfully.")
