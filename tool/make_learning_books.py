#!/usr/bin/env python3
"""Writes the items files of the Arabic letters and Colors books.

    python3 tool/make_learning_books.py

The words, letter names and colours live here; the 3D models come from
tool/make_shapes.py (run it next: it also fills in each colour scene's parts).
Then run make_pages.py and compile_targets.py with --book=letters_ar and
--book=colors.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AR = ROOT / "app" / "assets" / "ar" / "books"

# A rainbow for the letters, one colour per page in turn.
RAINBOW = ["#E4572E", "#F29E1F", "#E8B90C", "#4CAF50", "#1E88E5", "#7E57C2", "#D81B60", "#00897B"]

# Arabic: letter, its name (spoken), the word, the word in English and French,
# the photo, whether the letter joins the next one (has initial/medial forms).
ARABIC = [
    ("ا", "أَلِف", "أسد", "lion", "lion", "lion", False),
    ("ب", "باء", "بقرة", "cow", "vache", "cow", True),
    ("ت", "تاء", "تفاحة", "apple", "pomme", "apple", True),
    ("ث", "ثاء", "ثعلب", "fox", "renard", "fox", True),
    ("ج", "جيم", "جمل", "camel", "chameau", "camel", True),
    ("ح", "حاء", "حصان", "horse", "cheval", "horse", True),
    ("خ", "خاء", "خروف", "sheep", "mouton", "sheep", True),
    ("د", "دال", "دب", "bear", "ours", "bear", False),
    ("ذ", "ذال", "ذرة", "corn", "maïs", "corn", False),
    ("ر", "راء", "رمان", "pomegranate", "grenade", "pomegranate", False),
    ("ز", "زاي", "زرافة", "giraffe", "girafe", "giraffe", False),
    ("س", "سين", "سيارة", "car", "voiture", "car", True),
    ("ش", "شين", "شاحنة", "truck", "camion", "truck", True),
    ("ص", "صاد", "صقر", "falcon", "faucon", "falcon", True),
    ("ض", "ضاد", "ضفدع", "frog", "grenouille", "frog", True),
    ("ط", "طاء", "طائرة", "airplane", "avion", "airplane", True),
    ("ظ", "ظاء", "ظبي", "gazelle", "gazelle", "gazelle", True),
    ("ع", "عين", "عصفور", "sparrow", "moineau", "sparrow", True),
    ("غ", "غين", "غيمة", "cloud", "nuage", "cloud", True),
    ("ف", "فاء", "فيل", "elephant", "éléphant", "elephant", True),
    ("ق", "قاف", "قطة", "cat", "chat", "cat", True),
    ("ك", "كاف", "كلب", "dog", "chien", "dog", True),
    ("ل", "لام", "لقلق", "stork", "cigogne", "stork", True),
    ("م", "ميم", "موز", "banana", "banane", "banana", True),
    ("ن", "نون", "نحلة", "bee", "abeille", "bee", True),
    ("ه", "هاء", "هدهد", "hoopoe", "huppe", "hoopoe", True),
    ("و", "واو", "وردة", "rose", "rose", "rose", False),
    ("ي", "ياء", "يمامة", "dove", "colombe", "dove", True),
]
ARABIC_LATIN = ["Alif", "Baa", "Taa", "Thaa", "Jiim", "Haa", "Khaa", "Daal", "Thaal", "Raa", "Zaay", "Siin",
                "Shiin", "Saad", "Daad", "Taa", "Thaa", "Ayn", "Ghayn", "Faa", "Qaaf", "Kaaf", "Laam", "Miim",
                "Nuun", "Haa", "Waaw", "Yaa"]

# Colours: id, hex, names, the spoken "find" question, a fact.
COLORS = [
    ("red", "#E53935", "Red", "Rouge", "أحمر", "le rouge", "الأحمر",
     ("Strawberries and fire trucks are red.", "Les fraises et les camions de pompiers sont rouges.",
      "الفراولة وشاحنة الإطفاء لونهما أحمر.")),
    ("orange", "#FB8C00", "Orange", "Orange", "برتقالي", "l'orange", "البرتقالي",
     ("Oranges and carrots are orange.", "Les oranges et les carottes sont orange.", "البرتقال والجزر لونهما برتقالي.")),
    ("yellow", "#FDD835", "Yellow", "Jaune", "أصفر", "le jaune", "الأصفر",
     ("Bananas and the sun are yellow.", "Les bananes et le soleil sont jaunes.", "الموز والشمس لونهما أصفر.")),
    ("green", "#43A047", "Green", "Vert", "أخضر", "le vert", "الأخضر",
     ("Grass and frogs are green.", "L'herbe et les grenouilles sont vertes.", "العشب والضفدع لونهما أخضر.")),
    ("blue", "#1E88E5", "Blue", "Bleu", "أزرق", "le bleu", "الأزرق",
     ("The sky and the sea are blue.", "Le ciel et la mer sont bleus.", "السماء والبحر لونهما أزرق.")),
    ("purple", "#8E24AA", "Purple", "Violet", "بنفسجي", "le violet", "البنفسجي",
     ("Grapes and eggplants can be purple.", "Le raisin et l'aubergine peuvent être violets.",
      "العنب والباذنجان قد يكونان بنفسجيين.")),
    ("pink", "#EC6FA9", "Pink", "Rose", "وردي", "le rose", "الوردي",
     ("Flamingos are pink.", "Les flamants sont roses.", "طيور النحام لونها وردي.")),
    ("brown", "#795548", "Brown", "Marron", "بني", "le marron", "البني",
     ("Bears and chocolate are brown.", "Les ours et le chocolat sont marron.", "الدب والشوكولاتة لونهما بني.")),
    ("black", "#2B2B2B", "Black", "Noir", "أسود", "le noir", "الأسود",
     ("The night sky is black.", "Le ciel de la nuit est noir.", "سماء الليل سوداء.")),
    ("white", "#F5F5F5", "White", "Blanc", "أبيض", "le blanc", "الأبيض",
     ("Milk and snow are white.", "Le lait et la neige sont blancs.", "الحليب والثلج لونهما أبيض.")),
]


def arabic_forms(letter, joins):
    t = "ـ"  # tatweel shows the joined shapes
    return [letter, letter + t, t + letter + t, t + letter] if joins else [letter, t + letter]


def letters_ar():
    items = []
    for i, ((ch, name, word, en, fr, photo, joins), latin) in enumerate(zip(ARABIC, ARABIC_LATIN)):
        items.append({
            "id": f"ar_{i + 1:02d}", "page": i + 1,
            "en": f"{latin} · {en.capitalize()}", "fr": f"{latin} · {fr.capitalize()}", "ar": f"{ch} · {word}",
            "fr_of": f"de la lettre {latin}", "ar_def": f"حرف {name}",
            "fact_en": f"{en.capitalize()} ({word}) starts with the letter {latin}.",
            "fact_fr": f"{fr.capitalize()} ({word}) commence par la lettre {latin}.",
            "fact_ar": f"كلمة {word} تبدأ بحرف {name}.",
            "letter": ch, "forms": arabic_forms(ch, joins), "word": word, "photo": photo,
            "say": f"{name}. {word}", "say_lang": "ar",
            "model": f"books/letters_ar/models/ar_{i + 1:02d}.glb", "sound": None,
            "color": RAINBOW[i % len(RAINBOW)], "size": 0.42, "lift": 0, "turn": 0,
            "helps": {"en": f"Where is the letter {latin}?", "fr": f"Où est la lettre {latin} ?",
                      "ar": f"أين حرف ال{name}؟" if not name.startswith("أ") else f"أين حرف {name}؟"},
            "helps_say": f"أين حرف {name}؟",
            "parts": [],
        })
    return items


def colors():
    items = []
    for i, (cid, hexc, en, fr, ar, fr_def, ar_def, (fen, ffr, far)) in enumerate(COLORS):
        items.append({
            "id": f"color_{cid}", "page": i + 1, "en": en, "fr": fr, "ar": ar,
            "fr_of": f"du {fr_def[3:]}" if fr_def.startswith("le ") else f"de {fr_def}", "ar_def": f"اللون {ar_def}",
            "fact_en": fen, "fact_fr": ffr, "fact_ar": far,
            "model": f"books/colors/models/{cid}.glb", "sound": None,
            "say": None,
            "color": hexc, "size": 0.62, "lift": 0, "turn": 0,
            "needs": [cid],
            "helps": {"en": f"Find the colour {en.lower()}!", "fr": f"Trouve la couleur {fr.lower()} !",
                      "ar": f"ابحث عن اللون {ar_def}!"},
            "parts": [],  # filled in by make_shapes.py: the objects in the scene
        })
    return items


def write(book, items):
    d = AR / book
    for sub in ["models", "pages", "thumbs"]:
        (d / sub).mkdir(parents=True, exist_ok=True)
    f = d / "items.json"
    if f.exists():  # keep the parts make_shapes.py measured
        old = {x["id"]: x for x in json.loads(f.read_text())}
        for it in items:
            if not it["parts"] and old.get(it["id"], {}).get("parts"):
                it["parts"] = old[it["id"]]["parts"]
    f.write_text(json.dumps(items, ensure_ascii=False, indent=1))
    print("wrote", f.relative_to(ROOT), len(items))


if __name__ == "__main__":
    write("letters_ar", letters_ar())
    write("colors", colors())
