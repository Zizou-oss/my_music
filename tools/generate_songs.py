import os
import json

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
AUDIO_DIR = os.path.join(CURRENT_DIR, "../assets/audio")
OUTPUT_FILE = os.path.join(CURRENT_DIR, "../assets/songs.json")
GLOBAL_COVER = "cover.jpg"

songs = []
song_id = 1

for file in sorted(os.listdir(AUDIO_DIR)):
    if file.lower().endswith((".m4a", ".mp3")):
        name = os.path.splitext(file)[0]

        songs.append({
            "id": song_id,
            "title": name.replace("_", " ").title(),
            "file": file,
            "cover": GLOBAL_COVER
        })

        song_id += 1

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(songs, f, indent=2, ensure_ascii=False)

print("songs.json généré avec succès (cover unique).")
