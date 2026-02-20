import numpy as np
import os
import soundfile as sf

os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

from mlx_audio.tts.utils import load_model


audio_dict = {
    "daisy": {
        "audio": "/Users/daisy/Audio/大江东去.m4a",
        "text": "大江东去，浪淘尽，千古风流人物",
    },
    "azi": {
        "audio": "/Users/daisy/Audio/azi.wav",
        "text": "但是我当时我想了挺多话我这会儿我搞忘怎么说了。",
    },
    "guanguan": {
        "audio": "/Users/daisy/Audio/guanguan.wav",
        "text": "但是这么一说我谈过女朋友，但是我的女朋友后来才知道我是女孩子啊。",
    },
    "xt": {
        "audio": "/Users/daisy/Audio/xt.wav",
        "text": "打火机感觉不如毛老光的，顺丰哪有顺手快，自从老光去了游科之后，我就顺不到什么打火机了",
    },
}

speaker = "xt"
print(f"Using speaker: {speaker}")

model = load_model("mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16")
print(f"Model's sample rate is {model.sample_rate} ({model.sample_rate / 1000:.2f} kHz)")

results = list(
    model.generate(
        text="The more you buy, the more you save. Remember this when you purchase hardware at NVIDIA.",
        ref_audio=audio_dict[speaker]["audio"],
        ref_text=audio_dict[speaker]["text"],
    )
)

audio = results[0].audio
audio_np = np.array(audio)  # (samples,)

# Save numpy array as mono audio
out_path = "output.wav"
sf.write(out_path, audio_np, model.sample_rate)
print(f"Audio saved to {out_path}")
