#!/usr/bin/env python3
"""15 stabil kategoriye keyword-based otomatik atama.

Her entry'nin TR ve KMR tanımlarını (+ tr_meaning_overrides'taki TR'sini)
tarayıp kategoriye uygun anahtar kelime varsa o kategoriye ekle.

Input: assets/ferheng/entries.ndjson.gz, tr_meaning_overrides.json.gz
Output: entries.ndjson.gz overwritten with updated 'categories' field
"""
from __future__ import annotations

import gzip
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "ferheng"
ENTRIES = ASSETS / "entries.ndjson.gz"
OVERRIDES = ASSETS / "tr_meaning_overrides.json.gz"

# Her kategori için anahtar kelimeler (TR + KMR). Substring match'i için lemma
# kökleri kullanılır — Türkçe çekimleri kapsasın diye ("köpek" → köpeği, köpekler).
# False positive minimize için kategori bazlı ELE alın (örn. "renk" colors için
# ama "renklendirmek" gibi türevi de yakalar — kabul).
CATEGORIES = {
    "animals": {
        "tr": ["hayvan", "köpek", "kedi", "kuş", "balık", "böcek", "sürüngen",
               "fare", "fil", "aslan", "kaplan", "kurt", "ayı", "tilki", "tavşan",
               "at", "eşek", "katır", "deve", "inek", "öküz", "boğa", "buzağı",
               "koyun", "kuzu", "keçi", "oğlak", "domuz", "tavuk", "horoz",
               "civciv", "ördek", "kaz", "hindi", "güvercin", "serçe", "karga",
               "kartal", "şahin", "baykuş", "leylek", "kelebek", "arı", "karınca",
               "örümcek", "yılan", "kertenkele", "kurbağa", "yengeç", "ahtapot",
               "köpekbalığı", "yunus", "balina", "geyik", "ceylan", "zürafa",
               "fok", "panda", "maymun", "şempanze"],
        "kmr": ["heywan", "kûçik", "pisîk", "çûk", "masî", "kêz", "miş", "fîl",
                "şêr", "piling", "gur", "hirç", "rovî", "kerwêşk", "hesp", "ker",
                "deve", "çêl", "ga", "berx", "bizin", "kar", "berez", "mirîşk",
                "dîk", "çêlîk", "miravî", "qaz", "kewîtî", "kevok", "qijik",
                "qertel", "baz", "kund", "stork", "perwane", "mêş", "morî",
                "mar", "kûsî", "beq"],
    },
    "body": {
        "tr": ["vücut", "beden", "organ", "kafa", "baş", "göz", "kulak", "burun",
               "ağız", "dil", "diş", "dudak", "yanak", "çene", "alın", "kaş",
               "kirpik", "saç", "sakal", "bıyık", "boyun", "omuz", "kol", "dirsek",
               "el", "parmak", "tırnak", "avuç", "göğüs", "karın", "bel", "sırt",
               "kalça", "bacak", "diz", "ayak", "topuk", "kalp", "ciğer", "akciğer",
               "böbrek", "mide", "bağırsak", "damar", "kan", "kemik", "kas",
               "deri", "ten"],
        "kmr": ["beden", "endam", "ser", "çav", "guh", "poz", "dev", "ziman",
                "diran", "lêv", "rû", "çenge", "eniya", "birû", "porr", "ridî",
                "stû", "mil", "milok", "dest", "tilî", "neynûk", "sing", "zik",
                "pişt", "kemax", "ling", "çok", "pê", "dil", "ceger", "gurçik",
                "mîde", "rovî", "rehe", "xwîn", "hestî", "masûl", "çerm"],
    },
    "family": {
        "tr": ["aile", "anne", "baba", "ana", "kardeş", "abi", "abla", "kız",
               "oğul", "evlat", "çocuk", "bebek", "torun", "dede", "büyükbaba",
               "babaanne", "anneanne", "dayı", "amca", "hala", "teyze", "yeğen",
               "kayınvalide", "kayınpeder", "gelin", "damat", "kayınbirader",
               "kayınbaba", "kayınvalide", "eş", "koca", "karı", "hanım", "bey",
               "akraba"],
        "kmr": ["malbat", "dayîk", "diya", "bav", "xwişk", "bira", "keç", "kur",
                "zarrok", "zarro", "pitik", "neviya", "neviyê", "kalik", "dapîr",
                "dap îr", "xal", "mam", "met", "xaltî", "biraz", "xwarz", "bûk",
                "zava", "jin", "mêr", "hevser"],
    },
    "food": {
        "tr": ["yemek", "yiyecek", "yiyeti", "yiyecek", "içecek", "yiyim",
               "ekmek", "su", "süt", "yoğurt", "peynir", "tereyağı", "yağ",
               "et", "tavuk eti", "balık eti", "kıyma", "köfte", "tavuk", "balık",
               "sebze", "meyve", "domates", "salatalık", "biber", "patlıcan",
               "soğan", "sarımsak", "patates", "havuç", "marul", "lahana",
               "elma", "armut", "üzüm", "muz", "portakal", "limon", "çilek",
               "karpuz", "kavun", "kiraz", "şeftali", "kayısı", "incir", "ceviz",
               "fındık", "badem", "fıstık", "çikolata", "şeker", "tuz", "biber",
               "baharat", "sirke", "yumurta", "tahıl", "pirinç", "bulgur",
               "makarna", "çorba", "salata", "pilav", "börek", "baklava",
               "çay", "kahve", "şarap", "bira", "ayran"],
        "kmr": ["xwarin", "vexwarin", "nan", "av", "şîr", "mast", "penîr", "rûn",
                "goşt", "miravî", "kebab", "sebze", "fêkî", "firotî", "îşbar",
                "sîr", "pîvaz", "petate", "kartol", "marûl", "sêv", "hirmê",
                "tirî", "muz", "portaqal", "lîmon", "tût", "kelîjok", "qehwe",
                "tirş", "şor", "şîrîn", "tatlî", "ardî", "birinc", "bilgur",
                "şîlemar", "şorbe", "salata", "pilav", "kek"],
    },
    "nature": {
        "tr": ["doğa", "dağ", "tepe", "yamac", "vadi", "ova", "çöl", "ada",
               "yarımada", "deniz", "göl", "nehir", "ırmak", "dere", "çay",
               "kaynak", "şelale", "okyanus", "kıyı", "kumsal", "plaj", "kayalık",
               "kaya", "taş", "kum", "toprak", "çamur", "orman", "koru", "çayır",
               "çimen", "ot", "yaprak", "ağaç", "kök", "dal", "tomurcuk", "çiçek",
               "tohum", "meyve", "bulut", "yağmur", "kar", "sis", "rüzgar",
               "fırtına", "şimşek", "yıldırım", "gökkuşağı", "güneş", "ay",
               "yıldız", "gezegen", "evren", "uzay", "yeryüzü", "dünya", "gökyüzü"],
        "kmr": ["xweza", "çiya", "geli", "deşt", "çol", "dûriya", "behr", "gol",
                "robar", "çem", "kanî", "okyanûs", "bezê", "kûm", "kevir", "ax",
                "herî", "daristan", "mêrg", "giha", "pel", "dar", "rîs", "şax",
                "kulîlk", "tov", "ewr", "baran", "berf", "duman", "ba", "bahoz",
                "birûsk", "tîrêja rojê", "roj", "heyv", "stêr", "esman", "erd"],
    },
    "time": {
        "tr": ["zaman", "an", "saniye", "dakika", "saat", "gün", "gece",
               "sabah", "öğlen", "akşam", "öğleden sonra", "hafta", "ay (zaman)",
               "yıl", "asır", "yüzyıl", "çağ", "devir", "dönem", "mevsim",
               "ilkbahar", "yaz", "sonbahar", "kış", "bugün", "yarın", "dün",
               "şimdi", "henüz", "az önce", "geçmiş", "gelecek", "ertesi gün"],
        "kmr": ["dem", "gav", "deqîqe", "saet", "roj", "şev", "sibe", "nîvro",
                "êvar", "hefte", "meha", "salê", "sedsalî", "demsal", "bihar",
                "havîn", "payîz", "zivistan", "îro", "sibê", "duh", "niha",
                "borî", "pêşeroj"],
    },
    "numbers": {
        "tr": ["sayı", "rakam", "sıfır", "bir", "iki", "üç", "dört", "beş",
               "altı", "yedi", "sekiz", "dokuz", "on", "yirmi", "otuz", "kırk",
               "elli", "altmış", "yetmiş", "seksen", "doksan", "yüz", "bin",
               "milyon", "milyar", "birinci", "ikinci", "üçüncü", "yarım",
               "çeyrek", "tek (sayı)", "çift (sayı)"],
        "kmr": ["hejmar", "sifir", "yek", "du", "sê", "çar", "pênc", "şeş",
                "heft", "heşt", "neh", "deh", "bîst", "sî", "çil", "pêncî",
                "şêst", "heftê", "heştê", "nod", "sed", "hezar", "milyon",
                "yekem", "duyem", "sêyem", "nîv", "çarçik"],
    },
    "colors": {
        "tr": ["renk", "renkli", "kırmızı", "kızıl", "mavi", "yeşil", "sarı",
               "beyaz", "ak", "siyah", "kara", "mor", "menekşe", "pembe",
               "gri", "kahverengi", "turuncu", "altın", "gümüş", "lacivert",
               "bordo"],
        "kmr": ["reng", "sor", "şîn", "kesk", "zer", "spî", "reş", "binefşî",
                "pembê", "boz", "qehweyî", "porteqalî", "zêr", "zîv"],
    },
    "verbs_common": {
        "tr": ["fiil", "etmek", "olmak", "yapmak", "etmek", "gitmek", "gelmek",
               "almak", "vermek", "görmek", "bakmak", "duymak", "işitmek",
               "konuşmak", "söylemek", "demek", "anlamak", "bilmek", "bilmek",
               "düşünmek", "sevmek", "istemek", "istek duymak", "yemek", "içmek",
               "uyumak", "uyanmak", "kalkmak", "oturmak", "durmak", "yürümek",
               "koşmak", "düşmek", "bulmak", "kaybetmek", "kazanmak", "vurmak",
               "açmak", "kapamak", "kapatmak", "çalışmak", "okumak", "yazmak"],
        "kmr": ["lêker", "kirin", "bûn", "çûn", "hatin", "girtin", "dan",
                "dîtin", "lê nêrîn", "bihîstin", "axaftin", "gotin", "fêmkirin",
                "zanîn", "fikirîn", "hez kirin", "xwestin", "xwarin", "vexwarin",
                "razan", "hişyar bûn", "rûniştin", "westîn", "meşîn", "bezîn",
                "ketin", "dîtin", "winda kirin", "qezenc kirin", "vekirin",
                "girtin", "kar kirin", "xwendin", "nivîsîn"],
    },
    "clothing": {
        "tr": ["giyim", "elbise", "gömlek", "tişört", "pantolon", "etek",
               "şort", "ceket", "mont", "kaban", "palto", "yelek", "kazak",
               "atkı", "şal", "eldiven", "şapka", "bere", "kep", "kasket",
               "ayakkabı", "çizme", "terlik", "sandalet", "bot", "çorap",
               "tayt", "iç çamaşırı", "kemer", "kravat", "papyon", "saat",
               "yüzük", "küpe", "kolye", "bilezik", "gözlük", "şemsiye", "çanta"],
        "kmr": ["cil", "kinc", "berg", "kiras", "şal û şepik", "pantor", "şort",
                "kew", "qaftan", "şapik", "destkêş", "kum", "şarpûş", "çakêt",
                "soç", "çor", "kort", "rendê", "guhar", "gulîd", "bilezik",
                "qem", "hêliz"],
    },
    "home": {
        "tr": ["ev", "konut", "daire", "oda", "salon", "yatak odası", "mutfak",
               "banyo", "tuvalet", "balkon", "bahçe", "merdiven", "kapı",
               "pencere", "duvar", "tavan", "zemin", "çatı", "masa", "sandalye",
               "koltuk", "kanepe", "divan", "yatak", "yastık", "battaniye",
               "yorgan", "çarşaf", "halı", "kilim", "perde", "lamba", "ampul",
               "ayna", "dolap", "raf", "çekmece", "buzdolabı", "fırın",
               "ocak", "tencere", "tava", "tabak", "çatal", "kaşık", "bıçak",
               "bardak", "fincan"],
        "kmr": ["mal", "xanî", "ode", "oda", "salûn", "kuxin", "şuştin", "mitbax",
                "serşok", "tuwalet", "balkon", "bax", "derge", "pence", "dîwar",
                "ban", "qat", "ser", "mase", "kursî", "rakir", "kanape", "nivîn",
                "balgî", "betaniya", "tehlê", "ber", "tewîn", "xalî", "kilîm",
                "perde", "lampa", "neynik", "dolab", "rafê", "çekmece", "yexçal",
                "firne", "tendîr", "qab", "qantarme", "kefçî", "kêr", "qedeh"],
    },
    "places": {
        "tr": ["yer", "konum", "şehir", "il", "ilçe", "kasaba", "köy", "ülke",
               "vatan", "memleket", "sokak", "cadde", "bulvar", "yol", "meydan",
               "park", "bahçe", "mahalle", "semt", "alan", "bina", "kule",
               "okul", "üniversite", "hastane", "pazar", "çarşı", "market",
               "dükkan", "mağaza", "lokanta", "restoran", "kafe", "otel",
               "müze", "tiyatro", "sinema", "stadyum", "kütüphane", "kilise",
               "cami", "tapınak", "mezarlık"],
        "kmr": ["cih", "war", "bajar", "qeza", "navçeya", "gund", "welat",
                "dever", "kûçe", "rê", "kolan", "meydan", "park", "bax",
                "taxe", "navçe", "bîna", "qulle", "dibistan", "zankoy",
                "nexweşxane", "bazar", "sûk", "dukan", "xwarinxane", "kafe",
                "otel", "balxane", "şanod", "sînema", "stadyum", "pirtûkxane",
                "dêr", "mizgeft", "perestgeh", "goristan"],
    },
    "emotions": {
        "tr": ["duygu", "his", "mutlu", "sevinçli", "neşeli", "üzgün", "kederli",
               "kızgın", "öfkeli", "sinirli", "korkmuş", "korku", "heyecanlı",
               "heyecan", "şaşkın", "hayret", "şüpheli", "kıskanç", "utangaç",
               "utanç", "gurur", "övünç", "umut", "umutsuz", "yalnız",
               "yalnızlık", "sevgi", "aşk", "nefret", "kin", "merhamet",
               "acıma", "vicdan", "pişman", "pişmanlık", "huzur", "endişe",
               "kaygı", "stres", "gerilim"],
        "kmr": ["hest", "kêfxweş", "şa", "xemgîn", "tirsîyayî", "tirs",
                "matmayî", "şerm", "serbilind", "umîd", "kîn", "evîn", "hewce",
                "henç", "rûnandin", "westiyayî"],
    },
    "professions": {
        "tr": ["meslek", "iş", "doktor", "hekim", "öğretmen", "muallim",
               "mühendis", "avukat", "hakim", "savcı", "polis", "asker",
               "subay", "general", "çiftçi", "rençber", "işçi", "memur",
               "müdür", "patron", "sekreter", "muhasebeci", "mimar", "ressam",
               "sanatçı", "müzisyen", "şarkıcı", "oyuncu", "yazar", "şair",
               "gazeteci", "doktor", "hemşire", "eczacı", "diş hekimi",
               "veteriner", "şoför", "pilot", "kaptan", "denizci", "berber",
               "kuaför", "terzi", "ayakkabıcı", "fırıncı", "kasap", "manav",
               "garson", "aşçı", "temizlikçi"],
        "kmr": ["pîşe", "kar", "bijîjk", "doktor", "mamosta", "muhendis", "parêzer",
                "dadwer", "polês", "leşker", "afser", "cotkar", "karker",
                "karmend", "rêveber", "patron", "memur", "kateb", "mîmar",
                "wênesaz", "hunermend", "mûzîksaz", "stranbêj", "lîstikvan",
                "nivîskar", "helbestvan", "rojnamevan", "nexweş kar",
                "feyloz", "diranok", "veterîner", "şofêr", "pîlot", "qaptan",
                "behrkar", "berber", "terzî", "soltan", "fîrne kar", "qesabê",
                "selsel", "garson", "aşpêj", "paqijker"],
    },
    "religion_culture": {
        "tr": ["din", "kültür", "tanrı", "allah", "rab", "ilah", "peygamber",
               "elçi", "kutsal", "kutsiyet", "imam", "papaz", "rahip",
               "haham", "kilise", "cami", "havra", "tapınak", "namaz",
               "ibadet", "dua", "secde", "oruç", "iftar", "sahur", "bayram",
               "ramazan", "kurban", "hac", "umre", "ezan", "kuran", "incil",
               "tevrat", "zebur", "kitap", "ayet", "sure", "hadis", "cennet",
               "cehennem", "kıyamet", "ahiret", "ruh", "melek", "şeytan",
               "iblis", "günah", "sevap", "tövbe", "iman", "kafir", "müslüman",
               "hristiyan", "yahudi", "ezidi", "alevi", "sünni", "şii",
               "gelenek", "görenek", "âdet", "töre", "festival", "şenlik",
               "kutlama", "tören", "düğün", "cenaze", "nişan"],
        "kmr": ["ol", "çand", "xweda", "yezdan", "rabb", "pêxember", "qedîs",
                "îmam", "keşîş", "haxam", "dêr", "mizgeft", "perestgeh",
                "nimêj", "îbadet", "duahî", "secde", "rojî", "îftar", "cejn",
                "remezan", "qurban", "hec", "umre", "ezan", "qur'an", "încîl",
                "tewrat", "zebûr", "pirtûk", "ayet", "sûre", "hedîs", "biheşt",
                "cehnem", "qiyamet", "axret", "ruh", "milyaket", "şeytan",
                "îblîs", "guneh", "sewab", "tewbe", "îman", "kafir",
                "musulman", "mesihî", "cihû", "êzidî", "elewî", "sunî", "şîî",
                "kevneşop", "doçik", "feqd", "lihevcot", "rêûresm", "dawet",
                "şîna"],
    },
}


def normalize(s: str) -> str:
    return re.sub(r"\s+", " ", s.upper().strip())


def main() -> int:
    print("Loading entries + overrides...")
    with gzip.open(OVERRIDES, "rt", encoding="utf-8") as f:
        overrides = json.load(f).get("entries") or {}
    ov_lookup = {
        normalize(k): (v.get("tr") if isinstance(v, dict) else str(v))
        for k, v in overrides.items()
    }

    # Compile word-boundary regex per keyword set (min 4 chars to reduce
    # false positives from short common substrings like "ev", "an").
    cat_patterns = {}
    for cat, sets in CATEGORIES.items():
        tr_kws = [kw.lower().strip() for kw in sets["tr"] if len(kw.strip()) >= 4]
        kmr_kws = [kw.lower().strip() for kw in sets["kmr"] if len(kw.strip()) >= 4]
        if not tr_kws and not kmr_kws:
            continue
        tr_re = re.compile(r"\b(?:" + "|".join(re.escape(k) for k in tr_kws) + r")",
                           re.IGNORECASE) if tr_kws else None
        kmr_re = re.compile(r"\b(?:" + "|".join(re.escape(k) for k in kmr_kws) + r")",
                            re.IGNORECASE) if kmr_kws else None
        cat_patterns[cat] = (tr_re, kmr_re)

    # Process entries
    entries = []
    with gzip.open(ENTRIES, "rt", encoding="utf-8") as f:
        for line in f:
            entries.append(json.loads(line))
    print(f"Entries: {len(entries):,}")

    cat_counts = {c: 0 for c in CATEGORIES}
    updated = 0
    skipped_no_tr = 0
    injected_tr = 0
    for e in entries:
        n = normalize(e.get("normalized") or "")
        defs = e.get("definitions", {})
        tr_defs = [
            (d.get("gloss") or "").strip()
            for d in (defs.get("tr") or [])
            if (d.get("gloss") or "").strip()
        ]
        ov_tr = ov_lookup.get(n, "").strip()
        # TR yoksa kategori ekleme — kullanıcı kategoride açınca
        # her entry'de TR görsün. KMR-only entry'ler görünmesin.
        if not tr_defs and not ov_tr:
            # Eski kategorileri temizle (yanlış kategorizasyondan kalan)
            if (e.get("categories") or []):
                e["categories"] = []
                updated += 1
            skipped_no_tr += 1
            continue

        # Entry'de native TR yok ama override var → entry'ye INJECT et.
        # Bu sayede displayMeaning() ve liste tile'ları override'a
        # bakmadan TR'yi görür. UI tutarlılığı.
        if not tr_defs and ov_tr:
            defs["tr"] = [{"gloss": ov_tr, "examples": []}]
            e["definitions"] = defs
            tr_defs = [ov_tr]
            injected_tr += 1

        tr_text = " ".join(tr_defs).lower()
        kmr_text = " ".join(
            (d.get("gloss") or "")
            for d in (defs.get("kmr") or [])
        ).lower()
        if ov_tr:
            tr_text = tr_text + " " + ov_tr.lower()

        new_cats = []
        for cat, (tr_re, kmr_re) in cat_patterns.items():
            # Word-boundary match — TR'de daha sağlam, KMR'de yedek
            if tr_re is not None and tr_re.search(tr_text):
                new_cats.append(cat)
                continue
            if kmr_re is not None and kmr_re.search(kmr_text):
                new_cats.append(cat)
        # REPLACE (önceki bad-categorization'ı temizle)
        existing = e.get("categories") or []
        if new_cats != existing:
            e["categories"] = new_cats
            updated += 1
        for c in new_cats:
            cat_counts[c] += 1

    print(f"Skipped (no TR available): {skipped_no_tr:,}")
    print(f"Injected override TR into entry.definitions.tr: {injected_tr:,}")

    print(f"\nEntries newly tagged: {updated:,}")
    print(f"\nCategory totals after tagging:")
    for c in sorted(cat_counts, key=lambda x: -cat_counts[x]):
        print(f"  {c:<22} {cat_counts[c]:>7,}")

    # Write back
    with gzip.open(ENTRIES, "wt", encoding="utf-8") as f:
        for e in entries:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")
    print(f"\nWrote {ENTRIES}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
