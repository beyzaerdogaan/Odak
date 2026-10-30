#!/usr/bin/env python3
"""Writes the Kuzey göğü constellations (layer 2 of the sky) as Swift, from real star positions.

Star positions, magnitudes, names and stick figures come from the d3-celestial data set
(https://github.com/ofrohn/d3-celestial, BSD-3), which is on npm:

    npm pack d3-celestial@0.7.35 && tar xzf d3-celestial-0.7.35.tgz
    python3 design/tools/make_sky_catalog.py package/data

Each figure is projected around its own centre (gnomonic, north up, east left as seen from the
ground) and scaled to about 200 points. The Turkish texts below are hand-written; their English
lives in OdakCore's en.lproj/Localizable.strings.
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Packages/OdakCore/Sources/OdakCore/NorthernSky.swift"

GREEK = {"α": "Alpha", "β": "Beta", "γ": "Gamma", "δ": "Delta", "ε": "Epsilon", "ζ": "Zeta", "η": "Eta",
         "θ": "Theta", "ι": "Iota", "κ": "Kappa", "λ": "Lambda", "μ": "Mu", "ν": "Nu", "ξ": "Xi",
         "ο": "Omicron", "π": "Pi", "ρ": "Rho", "σ": "Sigma", "τ": "Tau", "υ": "Upsilon", "φ": "Phi",
         "χ": "Chi", "ψ": "Psi", "ω": "Omega"}
# Proper names are used for stars brighter than this; fainter ones go by their Bayer letter,
# except for names the facts mention.
NAME_MAG = 3.0
KEEP_NAMES = {"Thuban", "Sualocin", "Rotanev"}
BRIGHT_MAG = 1.3

# (d3 id, Swift id, Turkish name, Latin name, facts, where to look), in unlock order: the easy ones first.
NORTH = [
    ("Aur", "auriga", "Arabacı", "Auriga",
     ["Capella, gökyüzünün en parlak altıncı yıldızıdır ve aslında birbirinin çevresinde dönen iki sarı dev yıldızdır.",
      "Elnath yıldızı hem Arabacı'nın bir köşesi hem de Boğa'nın boynuzunun ucu olarak çizilir."],
     "Kış akşamları başının neredeyse tam üstünde, Avcı'nın kuzeyinde parlak Capella'yı bul."),
    ("Her", "hercules", "Herkül", "Hercules",
     ["Gövdesindeki dört yıldızın çizdiği yamuğa “Kilit Taşı” denir.",
      "Kilit Taşı'nın bir kenarında, dürbünle görülebilen Herkül Kümesi (M13) bulunur."],
     "Yaz akşamları başının üstünde, Vega ile Arcturus arasında ara."),
    ("Dra", "draco", "Ejderha", "Draco",
     ["Thuban, Mısır piramitleri yapılırken kutup yıldızıydı.",
      "Ejderha, Büyük Ayı ile Küçük Ayı arasında kıvrılarak uzanır."],
     "Yıl boyunca kuzeyde görülür. Başı, Vega'nın biraz kuzeyindeki küçük dörtgendir."),
    ("Cep", "cepheus", "Kral", "Cepheus",
     ["Kassiopeia'nın kocası Kral Kefeus'u temsil eder ve şekli bir evin çatısına benzer.",
      "Delta Cephei, uzaklık ölçmekte kullanılan değişen yıldızlara adını vermiştir."],
     "Yıl boyunca kuzeyde, Kassiopeia ile Kutup Yıldızı arasında görülür."),
    ("CrB", "corona-borealis", "Kuzey Tacı", "Corona Borealis",
     ["Yıldızları küçük, yarım daire şeklinde bir taç çizer.",
      "En parlak yıldızı Alphecca, tacın ortasındaki mücevher gibi durur."],
     "Bahar ve yaz akşamları Arcturus ile Vega arasında, Çoban'ın hemen doğusunda bak."),
    ("Cnc", "cancer", "Yengeç", "Cancer",
     ["Zodyak takımyıldızlarının en sönüğüdür.",
      "Ortasındaki Arı Kovanı Kümesi (M44), karanlık bir gökte çıplak gözle bulanık bir leke gibi görünür."],
     "Kış sonu ve bahar akşamları İkizler ile Aslan arasında ara."),
    ("Ari", "aries", "Koç", "Aries",
     ["Binlerce yıl önce ilkbahar noktası bu takımyıldızdaydı, bu yüzden zodyak sıralaması Koç ile başlar.",
      "En parlak yıldızı Hamal, turuncu bir dev yıldızdır."],
     "Sonbahar ve kış akşamları Ülker'in batısında, Andromeda'nın güneyinde görülür."),
    ("Oph", "ophiuchus", "Yılancı", "Ophiuchus",
     ["Güneş her yıl aralık başında bu takımyıldızın önünden geçer, ama Yılancı burçlardan sayılmaz.",
      "1604'te Kepler'in gözlediği süpernova bu takımyıldızda patlamıştır."],
     "Yaz akşamları güneyde, Akrep'in kuzeyinde ve Herkül'ün altında görülür."),
    ("CMi", "canis-minor", "Küçük Köpek", "Canis Minor",
     ["Procyon, Sirius ve Betelgeuse ile birlikte Kış Üçgeni'ni oluşturur.",
      "Procyon bize en yakın yıldızlardan biridir. Işığı bize yaklaşık 11 yılda ulaşır."],
     "Kış akşamları Avcı'nın doğusunda, İkizler'in güneyinde parlak Procyon'u bul."),
    ("Del", "delphinus", "Yunus", "Delphinus",
     ["Küçük ama belirgin şekli, sudan sıçrayan bir yunusa benzer.",
      "Sualocin ve Rotanev yıldızlarının adları, onlara ad veren gökbilimcinin Latince adının tersten yazılışıdır."],
     "Yaz ve sonbahar akşamları Altair'in kuzeydoğusunda ara."),
    ("Sge", "sagitta", "Ok", "Sagitta",
     ["Gökyüzünün en küçük üçüncü takımyıldızıdır.",
      "Yaz Üçgeni'nin içinde, Kartal ile Kuğu arasında uçan bir oku andırır."],
     "Yaz akşamları Altair'in hemen kuzeyinde bak."),
    ("Psc", "pisces", "Balıklar", "Pisces",
     ["İlkbahar noktası bugün bu takımyıldızın içindedir.",
      "Batıdaki balığın başı, küçük bir yıldız halkası çizer."],
     "Sonbahar akşamları Pegasus'un Büyük Karesi'nin güneyinde ve doğusunda uzanır."),
    ("Tri", "triangulum", "Üçgen", "Triangulum",
     ["Üç yıldızı dar bir üçgen çizer.",
      "Yakınındaki Üçgen Galaksisi (M33), çok karanlık bir gökte çıplak gözle seçilebilen en uzak cisimlerdendir."],
     "Sonbahar akşamları Andromeda ile Koç arasında bak."),
    ("Com", "coma-berenices", "Berenike'nin Saçı", "Coma Berenices",
     ["Adını, saçlarını tanrılara adayan Mısır kraliçesi Berenike'den alır.",
      "Bu yönde Samanyolu'nun dışına bakarız, bu yüzden bölge binlerce uzak galaksiyle doludur."],
     "Bahar akşamları Aslan'ın kuyruğu ile Arcturus arasında sönük bir yıldız serpintisi olarak görülür."),
    ("LMi", "leo-minor", "Küçük Aslan", "Leo Minor",
     ["17. yüzyılda Johannes Hevelius tarafından tanımlanmıştır.",
      "Büyük Ayı ile Aslan arasındaki boşluğu doldurur."],
     "Bahar akşamları Aslan'ın başının hemen kuzeyinde ara."),
    ("Lac", "lacerta", "Kertenkele", "Lacerta",
     ["Kuğu ile Andromeda arasında zikzak çizen küçük bir takımyıldızdır.",
      "O da 17. yüzyılda Hevelius tarafından tanımlanmıştır."],
     "Sonbahar akşamları Kuğu'nun doğusunda, Kassiopeia'nın güneyinde bak."),
    ("Vul", "vulpecula", "Tilki", "Vulpecula",
     ["İçindeki Halter Bulutsusu (M27), keşfedilen ilk gezegenimsi bulutsudur.",
      "Yaz Üçgeni'nin içinde yer alır."],
     "Yaz akşamları Kuğu'nun başı Albireo ile Ok arasında ara."),
    ("Equ", "equuleus", "Tay", "Equuleus",
     ["Güney Haçı'ndan sonra gökyüzünün en küçük ikinci takımyıldızıdır.",
      "Pegasus'un burnunun hemen yanında, onun küçük tayı gibi durur."],
     "Sonbahar akşamları Yunus ile Pegasus arasında bak."),
    ("Ser", "serpens", "Yılan", "Serpens",
     ["İki parçaya bölünmüş tek takımyıldızdır, çünkü Yılancı yılanı iki elinde tutar.",
      "Kuyruk kısmında Kartal Bulutsusu (M16) yer alır."],
     "Yaz akşamları Yılancı'nın iki yanında, Kuzey Tacı'nın güneyinde başlar."),
    ("Lyn", "lynx", "Vaşak", "Lynx",
     ["Adını, onu görmek için vaşak gibi keskin gözler gerektiğini söyleyen Hevelius vermiştir.",
      "Yıldızlarının çoğu sönüktür, karanlık bir gök ister."],
     "Kış ve bahar akşamları Büyük Ayı ile Arabacı arasındaki boşlukta bak."),
    ("CVn", "canes-venatici", "Av Köpekleri", "Canes Venatici",
     ["Çoban'ın tasmayla tuttuğu iki av köpeğini temsil eder.",
      "Girdap Galaksisi (M51) bu takımyıldızın sınırları içindedir."],
     "Bahar akşamları Büyük Ayı'nın kuyruğunun hemen güneyinde bak."),
    ("Cam", "camelopardalis", "Zürafa", "Camelopardalis",
     ["Kutup Yıldızı'na yakın, geniş ama çok sönük bir takımyıldızdır.",
      "17. yüzyılın başında Petrus Plancius tarafından tanımlanmıştır."],
     "Yıl boyunca kuzeyde, Kassiopeia ile Büyük Ayı arasında ara."),
]


def star_name(names, hip, mag, genitive):
    n = names.get(str(hip), {})
    proper = (n.get("name") or "").strip()
    if proper and (mag < NAME_MAG or proper in KEEP_NAMES):
        return proper
    bayer = (n.get("bayer") or "").rstrip("0123456789")
    if bayer in GREEK:
        return f"{GREEK[bayer]} {genitive}"
    if n.get("flam"):
        return f"{n['flam']} {genitive}"
    if proper:
        return proper
    return (n.get("hd") or f"HIP {hip}").replace("\u2009", " ").strip()


def size(mag):
    return round(max(1.1, min(3.0, 2.8 - 0.42 * mag)), 1)


def project(points):
    """Gnomonic projection around the figure's centre, north up and east to the left."""
    xs = [math.radians(p[0]) for p in points]
    ra0 = math.atan2(sum(map(math.sin, xs)), sum(map(math.cos, xs)))
    dec0 = math.radians(sum(p[1] for p in points) / len(points))
    out = []
    for ra, dec in points:
        ra, dec = math.radians(ra), math.radians(dec)
        cosc = math.sin(dec0) * math.sin(dec) + math.cos(dec0) * math.cos(dec) * math.cos(ra - ra0)
        x = math.cos(dec) * math.sin(ra - ra0) / cosc
        y = (math.cos(dec0) * math.sin(dec) - math.sin(dec0) * math.cos(dec) * math.cos(ra - ra0)) / cosc
        out.append((-x, -y))
    minx, miny = min(p[0] for p in out), min(p[1] for p in out)
    span = max(max(p[0] for p in out) - minx, max(p[1] for p in out) - miny) or 1
    return [(round((p[0] - minx) / span * 200), round((p[1] - miny) / span * 200)) for p in out]


def swift_string(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main(data):
    data = Path(data)
    # Serpens comes as two features, head and tail, under the same id.
    lines = {}
    for f in json.loads((data / "constellations.lines.json").read_text())["features"]:
        lines.setdefault(f["id"], []).extend(f["geometry"]["coordinates"])
    meta = {f["id"]: f["properties"] for f in json.loads((data / "constellations.json").read_text())["features"]}
    names = json.loads((data / "starnames.json").read_text())
    stars = {}
    for f in json.loads((data / "stars.14.json").read_text())["features"]:
        stars[tuple(round(c, 3) for c in f["geometry"]["coordinates"])] = (f["id"], f["properties"]["mag"])

    blocks = []
    for d3id, cid, tr, latin, facts, look in NORTH:
        genitive = meta[d3id]["gen"]
        points, segments = [], []
        for path in lines[d3id]:
            keys = [tuple(round(c, 3) for c in p) for p in path]
            for k in keys:
                if k not in points:
                    points.append(k)
            segments += list(zip(keys, keys[1:]))
        info = [stars[k] for k in points]
        labels = [star_name(names, hip, mag, genitive) for hip, mag in info]
        assert len(set(labels)) == len(labels), (cid, labels)
        xy = project(points)
        star_rows = [f'("{swift_string(l)}", {x}, {y}, {size(m)}, {"true" if m < BRIGHT_MAG else "false"})'
                     for l, (x, y), (_, m) in zip(labels, xy, info)]
        line_rows = [f'("{swift_string(labels[points.index(a)])}", "{swift_string(labels[points.index(b)])}")'
                     for a, b in segments]

        def wrap(rows, indent):
            out, cur = [], ""
            for r in rows:
                piece = (", " if cur else "") + r
                if cur and len(indent) + len(cur) + len(piece) > 118:
                    out.append(cur + ",")
                    cur = r
                else:
                    cur += piece
            out.append(cur)
            return ("\n" + indent).join(out)

        fact_rows = ",\n                  ".join(f'loc("{swift_string(f)}")' for f in facts)
        blocks.append(
            f'        c("{cid}", loc("{swift_string(tr)}"), "{latin}",\n'
            f'          stars: [{wrap(star_rows, " " * 18)}],\n'
            f'          lines: [{wrap(line_rows, " " * 18)}],\n'
            f'          facts: [{fact_rows}],\n'
            f'          look: loc("{swift_string(look)}")),'
        )

    OUT.write_text(
        "// Generated by design/tools/make_sky_catalog.py from d3-celestial star data. Do not edit by hand.\n\n"
        "extension Catalog {\n"
        "    /// Kuzey göğü: the 22 constellations north of the celestial equator that the starter sky leaves out,\n"
        "    /// in unlock order. They open one by one once the starter sky is complete.\n"
        "    public static let northern: [Constellation] = [\n"
        + "\n".join(blocks).rstrip(",") + "\n"
        "    ]\n"
        "}\n"
    )
    print(f"wrote {OUT.relative_to(ROOT)}: {len(NORTH)} constellations, "
          f"{sum(b.count('true)') + b.count('false)') for b in blocks)} stars")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "package/data")
