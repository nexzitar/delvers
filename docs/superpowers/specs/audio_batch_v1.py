"""Delvers audio library batch: ElevenLabs text-to-SFX, the Tripo
batch pattern for sound. Generates combat SFX, creature voices,
stingers and per-theme ambience beds into the game's audio dirs.
Usage: audio_batch.py [only_prefix]"""
import json, os, sys, time, urllib.request

KEY = open(os.path.expanduser("~/.venvs/tripo/elevenlabs_key")).read().strip()
ROOT = "/Users/mattias/delvers/audio"

# (path, prompt, duration_seconds or None, prompt_influence)
LIBRARY = [
    # --- Combat: steel and wood ---
    ("sfx/sword_swing_1.mp3", "quick sharp sword whoosh through air, short, no impact", 0.8, 0.5),
    ("sfx/sword_swing_2.mp3", "fast blade swish through air, slightly lower pitch, short", 0.8, 0.5),
    ("sfx/sword_hit_1.mp3", "sword striking leather armor, meaty thud with faint metal ring, short", 0.9, 0.5),
    ("sfx/sword_hit_2.mp3", "blade impact on padded armor, dull chop, short", 0.9, 0.5),
    ("sfx/shield_block.mp3", "sword clanging against a wooden shield with iron boss, sharp knock, short", 1.0, 0.5),
    ("sfx/crit_impact.mp3", "heavy brutal weapon impact with deep punchy crunch, short", 1.0, 0.6),
    ("sfx/bow_release.mp3", "bowstring twang and arrow whoosh leaving, short", 0.9, 0.5),
    ("sfx/arrow_hit.mp3", "arrow thudding into flesh with a small whip crack, short", 0.8, 0.5),
    # --- Creatures: the families speak ---
    ("sfx/slime_hop.mp3", "small gelatinous blob landing with a wet boing, cartoonish, short", 0.8, 0.4),
    ("sfx/slime_death.mp3", "gelatinous creature bursting with a wet splat and bubbling deflation, short", 1.4, 0.5),
    ("sfx/goblin_bark_1.mp3", "small goblin creature short aggressive bark yell, raspy high pitched", 1.0, 0.5),
    ("sfx/goblin_bark_2.mp3", "small goblin creature cackling war cry, raspy, short", 1.2, 0.5),
    ("sfx/goblin_death.mp3", "small goblin creature death cry, raspy yelp fading, short", 1.3, 0.5),
    ("sfx/goblin_chief_roar.mp3", "large goblin brute roaring a battle challenge, guttural, short", 1.6, 0.5),
    ("sfx/spider_hiss.mp3", "giant spider aggressive hiss with chittering mandibles, short", 1.2, 0.5),
    ("sfx/spider_skitter.mp3", "giant spider legs skittering fast on stone, short", 1.2, 0.4),
    ("sfx/spider_death.mp3", "giant insect screech cut short with a crunch, short", 1.3, 0.5),
    # --- Magic and healing ---
    ("sfx/heal_chime.mp3", "soft warm healing chime with gentle shimmer, magical, short", 1.4, 0.4),
    ("sfx/frost_nova.mp3", "burst of magical frost, crystalline crackle expanding, short", 1.4, 0.5),
    # --- The delve: stingers ---
    ("sfx/pack_pulled.mp3", "short tense orchestral danger sting, low strings hit and rising alarm, dungeon combat starting", 1.8, 0.4),
    ("sfx/loot_toast.mp3", "small satisfying treasure chime, coins and a soft bell, short", 1.2, 0.4),
    ("sfx/victory_sting.mp3", "short triumphant fantasy fanfare, warm brass and drum, victorious", 3.0, 0.4),
    ("sfx/defeat_sting.mp3", "short somber low drone with a falling minor phrase, defeat, dark fantasy", 3.0, 0.4),
    ("sfx/room_banner.mp3", "deep soft whoosh with faint stone rumble, a title revealing, short", 1.2, 0.4),
    # --- Ambience beds (looped in-engine) ---
    ("ambience/darkwood.mp3", "night forest ambience, wind through fir trees, distant owl, creaking branches, sparse and eerie, seamless loop", 22.0, 0.35),
    ("ambience/spider_nest.mp3", "deep cavern ambience, echoing water drips, faint skittering in the dark, low rumble, oppressive, seamless loop", 22.0, 0.35),
    ("ambience/sunken_workshop.mp3", "abandoned flooded machine hall ambience, slow dripping water, distant metal groans, faint dead engine hum, seamless loop", 22.0, 0.35),
]

def generate(path, prompt, duration, influence):
    body = {"text": prompt, "prompt_influence": influence}
    if duration:
        body["duration_seconds"] = duration
    req = urllib.request.Request(
        "https://api.elevenlabs.io/v1/sound-generation",
        data=json.dumps(body).encode(),
        headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        audio = r.read()
    out = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as f:
        f.write(audio)
    print("SAVED %s (%d bytes)" % (path, len(audio)), flush=True)

only = sys.argv[1] if len(sys.argv) > 1 else ""
for path, prompt, duration, influence in LIBRARY:
    if only and not path.startswith(only):
        continue
    for attempt in range(3):
        try:
            generate(path, prompt, duration, influence)
            break
        except Exception as e:
            print("RETRY %s: %s" % (path, e), flush=True)
            time.sleep(5)
    time.sleep(1.0)
print("AUDIO BATCH DONE", flush=True)
