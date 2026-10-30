#!/usr/bin/env python3
"""Writes the Kuzey göğü and Güney seferi constellations (layer 2 of the sky) as Swift, from real star positions.

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
SOURCES = ROOT / "Packages/OdakCore/Sources/OdakCore"

GREEK = {"α": "Alpha", "β": "Beta", "γ": "Gamma", "δ": "Delta", "ε": "Epsilon", "ζ": "Zeta", "η": "Eta",
         "θ": "Theta", "ι": "Iota", "κ": "Kappa", "λ": "Lambda", "μ": "Mu", "ν": "Nu", "ξ": "Xi",
         "ο": "Omicron", "π": "Pi", "ρ": "Rho", "σ": "Sigma", "τ": "Tau", "υ": "Upsilon", "φ": "Phi",
         "χ": "Chi", "ψ": "Psi", "ω": "Omega"}
# Proper names are used for stars brighter than this; fainter ones go by their Bayer letter,
# except for names the facts mention.
NAME_MAG = 3.0
KEEP_NAMES = {"Thuban", "Sualocin", "Rotanev", "Mira"}
BRIGHT_MAG = 1.3
# Names in the data set that would mislead: α Cen goes by the name the facts use, and a few uncommon names
# that clash with other stars (Alnair is also α Gru) give way to the Bayer letter.
RENAME = {"Toliman": "Alpha Centauri", "KeKouan": "", "Men": ""}
SUPERSCRIPT = str.maketrans("0123456789", "⁰¹²³⁴⁵⁶⁷⁸⁹")

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


# Güney seferi: the 50 constellations south of the celestial equator, from the ones Turkey sees low in
# the south to the ones around the south celestial pole.
NOT = "Türkiye'den görülmez. "
SOUTH = [
    ("CMa", "canis-major", "Büyük Köpek", "Canis Major",
     ["Sirius, gece gökyüzünün en parlak yıldızıdır ve yaklaşık 8,6 ışık yılı uzaktadır.",
      "Avcı'nın sadık köpeği olarak, onun hemen arkasından doğar."],
     "Kış akşamları Avcı'nın Kemeri'ni sola ve aşağı doğru uzatırsan Sirius'a varırsın."),
    ("Vir", "virgo", "Başak", "Virgo",
     ["Gökyüzünün en büyük ikinci takımyıldızıdır.",
      "Spica, Başak'ın elindeki buğday başağını temsil eder."],
     "Bahar akşamları güneyde, Büyük Ayı'nın kuyruğundan Arcturus'a, oradan Spica'ya uzanan kavisi takip et."),
    ("Lib", "libra", "Terazi", "Libra",
     ["Zodyakta canlı değil de bir nesneyi temsil eden tek takımyıldızdır.",
      "En parlak iki yıldızının adları “güney kıskacı” ve “kuzey kıskacı” demektir, çünkü eskiden Akrep'in kıskaçları sayılırlardı."],
     "Yaz başı akşamlarında güneyde, Başak ile Akrep arasında bak."),
    ("Cap", "capricornus", "Oğlak", "Capricornus",
     ["Yarı keçi, yarı balık bir yaratığı temsil eder.",
      "Zodyak takımyıldızlarının en küçüklerindendir."],
     "Sonbahar başı akşamlarında güneyde, Altair'in altında alçakta görülür."),
    ("Aqr", "aquarius", "Kova", "Aquarius",
     ["Gökyüzünün en eski takımyıldızlarındandır, Babilliler de onu biliyordu.",
      "Her yıl mayıs başında Eta Akuaridler meteor yağmuru buradan yağıyor gibi görünür."],
     "Sonbahar akşamları güneyde, Pegasus'un Büyük Karesi'nin altında ara."),
    ("Crv", "corvus", "Karga", "Corvus",
     ["Dört parlak yıldızı belirgin bir dörtgen çizer.",
      "Efsanede Suyılanı'nın sırtına konmuş bir kargadır."],
     "Bahar akşamları güneyde, Spica'nın batısında alçakta bak."),
    ("Lep", "lepus", "Tavşan", "Lepus",
     ["Avcı'nın ayaklarının dibinde, avdan kaçan bir tavşanı temsil eder.",
      "Gökyüzünün en kırmızı yıldızlarından Hind'in Kızıl Yıldızı bu takımyıldızdadır."],
     "Kış akşamları Avcı'nın hemen altında, Rigel'in güneyinde bak."),
    ("Hya", "hydra", "Suyılanı", "Hydra",
     ["Gökyüzünün en büyük takımyıldızıdır, başından kuyruğuna 100 dereceden uzun bir yay çizer.",
      "En parlak yıldızı Alphard “yalnız olan” demektir, çünkü çevresinde başka parlak yıldız yoktur."],
     "Bahar akşamları güneyde, başı Yengeç'in altında, kuyruğu Terazi'ye kadar uzanır."),
    ("Cet", "cetus", "Balina", "Cetus",
     ["Mira, yaklaşık 11 ayda bir parlayıp sönen ve ilk keşfedilen değişen yıldızlardan biridir.",
      "Efsanede Andromeda'yı yutmak isteyen deniz canavarıdır."],
     "Sonbahar akşamları güneyde, Balıklar ve Koç'un altında geniş bir alanda bak."),
    ("Eri", "eridanus", "Irmak", "Eridanus",
     ["Avcı'nın ayağından güney göğüne kadar kıvrılarak akan bir ırmağı temsil eder.",
      "Ucundaki parlak Achernar “ırmağın sonu” demektir ve Türkiye'den görülmez."],
     "Kış akşamları Rigel'in hemen yanından başlayıp güney ufkuna doğru kıvrılır."),
    ("Mon", "monoceros", "Tekboynuz", "Monoceros",
     ["Sönük bir takımyıldızdır ama Samanyolu'nun içinde, pek çok bulutsuya ev sahipliği yapar.",
      "Gül Bulutsusu ve Koni Bulutsusu bu takımyıldızdadır."],
     "Kış akşamları Betelgeuse, Sirius ve Procyon'un oluşturduğu Kış Üçgeni'nin ortasında ara."),
    ("Crt", "crater", "Kupa", "Crater",
     ["Apollon'un kupasını temsil eder ve Suyılanı'nın sırtında durur.",
      "Yıldızları sönüktür ama şekli gerçekten bir kadehe benzer."],
     "Bahar akşamları güneyde, Karga'nın batısında bak."),
    ("PsA", "piscis-austrinus", "Güney Balığı", "Piscis Austrinus",
     ["En parlak yıldızı Fomalhaut, sonbahar göğünün güney yanındaki en parlak yıldızdır.",
      "Fomalhaut'u geniş bir toz kuşağı çevreler."],
     "Sonbahar akşamları güney ufkunun üstünde, Kova'nın altında Fomalhaut'u bul."),
    ("CrA", "corona-australis", "Güney Tacı", "Corona Australis",
     ["Kuzey Tacı'nın güneydeki eşidir ve küçük bir yay çizer.",
      "Antik çağdan beri bilinen 48 takımyıldızdan biridir."],
     "Yaz akşamları güney ufkunun hemen üstünde, Yay'ın altında bak."),
    ("Lup", "lupus", "Kurt", "Lupus",
     ["Eskiden Erboğa'nın mızrağına takılmış bir hayvan olarak çizilirdi.",
      "1006 yılında burada parlayan süpernova, tarihte kaydedilmiş en parlak yıldız olayıdır."],
     "Yaz başı akşamlarında güney ufkunun hemen üstünde, Akrep'in batısında bak."),
    ("Cen", "centaurus", "Erboğa", "Centaurus",
     ["Alfa Centauri, Güneş'e en yakın yıldız sistemidir.",
      "Omega Centauri, Samanyolu'nun en büyük küresel yıldız kümesidir."],
     "Kuzey kısmı bahar akşamları güney ufkunda görülür, Alfa Centauri ise ancak daha güneyden görülür."),
    ("Col", "columba", "Güvercin", "Columba",
     ["Nuh'un gemisinden salınan güvercini temsil eder.",
      "16. yüzyılın sonunda Petrus Plancius tarafından tanımlanmıştır."],
     "Kış akşamları güney ufkunun hemen üstünde, Tavşan'ın altında bak."),
    ("Pup", "puppis", "Pupa", "Puppis",
     ["Eskiden Argo gemisi adlı dev bir takımyıldızın kıç kısmıydı.",
      "Argo sonradan Pupa, Yelken ve Karina olarak üçe bölünmüştür."],
     "Kış sonu akşamlarında güney ufkunun üstünde, Sirius'un güneydoğusunda bak."),
    ("Sct", "scutum", "Kalkan", "Scutum",
     ["Lehistan Kralı III. Jan Sobieski'nin kalkanını temsil eder ve 1684'te Hevelius tarafından tanımlanmıştır.",
      "Samanyolu'nun en parlak bölgelerinden Kalkan Yıldız Bulutu buradadır."],
     "Yaz akşamları güneyde, Kartal'ın altında ve Yay'ın üstünde bak."),
    ("Sex", "sextans", "Altılık", "Sextans",
     ["Hevelius'un yıldız konumlarını ölçtüğü aleti temsil eder.",
      "Çok sönüktür, en parlak yıldızı bile zor seçilir."],
     "Bahar akşamları Aslan'daki Regulus'un güneyinde bak."),
    ("Pyx", "pyxis", "Pusula", "Pyxis",
     ["Gemilerde kullanılan bir pusulayı temsil eder ve 18. yüzyılda Lacaille tarafından tanımlanmıştır.",
      "Eski Argo gemisinin direğinin yakınına yerleştirilmiştir."],
     "Kış sonu akşamlarında güney ufkunun üstünde, Pupa'nın doğusunda bak."),
    ("Ant", "antlia", "Pompa", "Antlia",
     ["Lacaille'ın bilim aletlerinden esinlenerek tanımladığı takımyıldızlardan biridir.",
      "Yıldızları çok sönüktür."],
     "Bahar akşamları güney ufkunun hemen üstünde, Suyılanı'nın altında ara."),
    ("For", "fornax", "Ocak", "Fornax",
     ["Bir kimya laboratuvarındaki ocağı temsil eder.",
      "Fornax Galaksi Kümesi, bize en yakın büyük galaksi kümelerinden biridir."],
     "Sonbahar akşamları güneyde, Balina'nın altında, Irmak'ın kıvrımında bak."),
    ("Scl", "sculptor", "Heykeltıraş", "Sculptor",
     ["Samanyolu'nun güney kutbu bu takımyıldızdadır.",
      "Heykeltıraş Galaksisi, dürbünle görülebilen parlak bir sarmal galaksidir."],
     "Sonbahar akşamları güney ufkunun hemen üstünde, Fomalhaut'un doğusunda bak."),
    ("Mic", "microscopium", "Mikroskop", "Microscopium",
     ["Lacaille tarafından mikroskobu anmak için tanımlanmıştır.",
      "Yıldızlarının hiçbiri 4. kadirden parlak değildir."],
     "Sonbahar başı akşamlarında güney ufkunun hemen üstünde, Oğlak'ın altında bak."),
    ("Gru", "grus", "Turna", "Grus",
     ["Uzun boyunlu bir turna kuşunu temsil eder.",
      "En parlak yıldızı Alnair mavi-beyaz renktedir."],
     "Sonbahar akşamları Türkiye'nin güneyinden ufkun hemen üstünde, Fomalhaut'un altında görülebilir."),
    ("Phe", "phoenix", "Anka", "Phoenix",
     ["Kendi küllerinden yeniden doğan efsanevi kuşu temsil eder.",
      "16. yüzyılın sonunda Hollandalı denizcilerin gözlemlerinden yola çıkılarak tanımlanmıştır."],
     "Sonbahar akşamları Türkiye'nin güney kıyılarından ufkun hemen üstünde görülebilir."),
    ("Cae", "caelum", "Çelikkalem", "Caelum",
     ["Bir oymacının kalemini temsil eder ve Lacaille tarafından tanımlanmıştır.",
      "Gökyüzünün en küçük ve en sönük takımyıldızlarından biridir."],
     "Kış akşamları güney ufkunun hemen üstünde, Güvercin'in batısında bak."),
    ("Vel", "vela", "Yelken", "Vela",
     ["Eski Argo gemisinin yelkenlerini temsil eder.",
      "Yelken Atarcası, saniyede yaklaşık 11 kez dönen bir nötron yıldızıdır."],
     "Türkiye'den yalnızca kuzey kenarı, kış sonu akşamlarında güney ufkunda görülür."),
    ("Car", "carina", "Karina", "Carina",
     ["Canopus, gece gökyüzünün en parlak ikinci yıldızıdır.",
      "Karina Bulutsusu, gökyüzündeki en büyük ve en parlak bulutsulardan biridir."],
     "Türkiye'nin güney kıyılarından Canopus, kış akşamları ufkun hemen üstünde kısa bir süre görülebilir. Gerisi için güneye gitmek gerekir."),
    ("Cru", "crux", "Güney Haçı", "Crux",
     ["Gökyüzünün en küçük takımyıldızıdır.",
      "Avustralya, Yeni Zelanda ve Brezilya bayraklarında yer alır."],
     NOT + "Güney yarımkürede nisan ve mayıs akşamları yüksekte durur."),
    ("Ara", "ara", "Sunak", "Ara",
     ["Tanrıların Titanlarla savaşmadan önce yemin ettiği sunağı temsil eder.",
      "Samanyolu'nun içinde, Akrep'in kuyruğunun güneyindedir."],
     NOT + "Güney yarımküreden yaz aylarında Akrep'in altında bak."),
    ("Nor", "norma", "Cetvel", "Norma",
     ["Bir marangoz gönyesini temsil eder ve Lacaille tarafından tanımlanmıştır.",
      "Samanyolu'nun yoğun yıldız alanlarının ortasında durur."],
     NOT + "Güney yarımküreden Akrep ile Erboğa arasında bak."),
    ("Tel", "telescopium", "Dürbün", "Telescopium",
     ["Lacaille tarafından teleskobu anmak için tanımlanmıştır.",
      "Eskiden yıldızlarının bir kısmı komşu takımyıldızlara aitti."],
     NOT + "Güney yarımküreden yaz aylarında Yay'ın altında bak."),
    ("Ind", "indus", "Hintli", "Indus",
     ["16. yüzyılın sonunda Hollandalı denizcilerin gözlemleriyle tanımlanmıştır.",
      "Epsilon Indi, Güneş'e en yakın yıldızlardan biridir ve yaklaşık 12 ışık yılı uzaktadır."],
     NOT + "Güney yarımküreden Turna ile Tavus arasında bak."),
    ("Pic", "pictor", "Ressam", "Pictor",
     ["Bir ressamın şövalesini temsil eder ve Lacaille tarafından tanımlanmıştır.",
      "Beta Pictoris'in çevresinde gezegenlerin oluştuğu bir toz diski vardır."],
     NOT + "Güney yarımküreden Canopus'un yakınında ara."),
    ("Hor", "horologium", "Saat", "Horologium",
     ["Sarkaçlı bir saati temsil eder ve Lacaille tarafından tanımlanmıştır.",
      "Uzun ve sönük bir yıldız zinciri çizer."],
     NOT + "Güney yarımküreden Achernar'ın yakınında ara."),
    ("Ret", "reticulum", "Ağcık", "Reticulum",
     ["Teleskoplarda yıldız konumu ölçmek için kullanılan ince bir ağı temsil eder.",
      "Küçük ama belirgin bir baklava şekli çizer."],
     NOT + "Güney yarımküreden Büyük Macellan Bulutu'nun yakınında ara."),
    ("Dor", "dorado", "Kılıçbalığı", "Dorado",
     ["Samanyolu'nun uydusu Büyük Macellan Bulutu'nun çoğu bu takımyıldızdadır.",
      "Büyük Macellan Bulutu'ndaki Tarantula Bulutsusu, bilinen en parlak yıldız doğum bölgelerinden biridir."],
     NOT + "Güney yarımkürede Büyük Macellan Bulutu'nu bulursan oradasın."),
    ("Pav", "pavo", "Tavus", "Pavo",
     ["En parlak yıldızının adı da Peacock, yani tavus kuşudur.",
      "Hollandalı denizcilerin gözlemleriyle tanımlanan 12 takımyıldızdan biridir."],
     NOT + "Güney yarımküreden güney kutbuna doğru, Hintli'nin yanında bak."),
    ("Tuc", "tucana", "Tukan", "Tucana",
     ["Küçük Macellan Bulutu bu takımyıldızdadır.",
      "47 Tucanae, gökyüzünün en parlak küresel kümelerinden biridir."],
     NOT + "Güney yarımkürede Küçük Macellan Bulutu'nun yanında bak."),
    ("Cir", "circinus", "Pergel", "Circinus",
     ["Çizim pergelini temsil eder ve Lacaille tarafından tanımlanmıştır.",
      "Alfa Centauri'nin hemen yanında küçük ve dar bir üçgen çizer."],
     NOT + "Güney yarımküreden Alfa Centauri'nin yanında bak."),
    ("TrA", "triangulum-australe", "Güney Üçgeni", "Triangulum Australe",
     ["Kuzeydeki Üçgen'den daha büyük ve daha parlaktır.",
      "Üç yıldızı, Samanyolu'nun hemen kenarında belirgin bir üçgen çizer."],
     NOT + "Güney yarımküreden Alfa Centauri'nin güneydoğusunda bak."),
    ("Mus", "musca", "Sinek", "Musca",
     ["Gökyüzündeki tek böcek takımyıldızıdır.",
      "Güney Haçı'nın hemen güneyinde durur."],
     NOT + "Güney yarımküreden Güney Haçı'nın altında bak."),
    ("Hyi", "hydrus", "Küçük Suyılanı", "Hydrus",
     ["Büyük Suyılanı ile karıştırılmasın, bu küçük yılan güney gök kutbunun yakınındadır.",
      "İki Macellan Bulutu'nun arasında uzanır."],
     NOT + "Güney yarımküreden Achernar ile güney gök kutbu arasında bak."),
    ("Vol", "volans", "Uçan Balık", "Volans",
     ["Tropik denizlerde sudan sıçrayan uçan balığı temsil eder.",
      "Karina'nın hemen güneyinde küçük bir takımyıldızdır."],
     NOT + "Güney yarımküreden Canopus ile güney gök kutbu arasında bak."),
    ("Cha", "chamaeleon", "Bukalemun", "Chamaeleon",
     ["Güney gök kutbuna çok yakın, küçük ve sönük bir takımyıldızdır.",
      "İçindeki karanlık bulutlarda bugün de yeni yıldızlar doğmaktadır."],
     NOT + "Güney yarımkürede güney gök kutbunun hemen yakınında bak."),
    ("Aps", "apus", "Cennetkuşu", "Apus",
     ["Adı Yunanca “ayaksız” demektir, çünkü Avrupa'ya getirilen cennetkuşu postlarında ayak olmazdı.",
      "Güney gök kutbuna yakın, sönük bir takımyıldızdır."],
     NOT + "Güney yarımküreden Güney Üçgeni'nin güneyinde bak."),
    ("Men", "mensa", "Masa", "Mensa",
     ["Gökyüzünde yeryüzündeki bir yerin, Güney Afrika'daki Masa Dağı'nın adını taşıyan tek takımyıldızdır.",
      "Büyük Macellan Bulutu'nun bir kısmı bu takımyıldıza taşar."],
     NOT + "Güney yarımküreden Büyük Macellan Bulutu'nun hemen altında bak."),
    ("Oct", "octans", "Sekizlik", "Octans",
     ["Güney gök kutbu bu takımyıldızın içindedir.",
      "Güneyin kutup yıldızı Sigma Octantis, çıplak gözle zor seçilecek kadar sönüktür."],
     NOT + "Güney yarımkürede gökyüzünün tam güney kutbunda durur."),
]

def star_name(names, hip, mag, genitive, numbered=False):
    n = names.get(str(hip), {})
    proper = (n.get("name") or "").strip()
    proper = RENAME.get(proper, proper)
    if proper and (mag < NAME_MAG or proper in KEEP_NAMES):
        return proper
    raw = n.get("bayer") or ""
    bayer = raw.rstrip("0123456789")
    if bayer in GREEK:
        # τ1 … τ9 Eridani and the like keep their number, as a superscript, where the letter alone is ambiguous.
        number = raw[len(bayer):].translate(SUPERSCRIPT) if numbered else ""
        return f"{GREEK[bayer]}{number} {genitive}"
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

    for region, table, file, doc in REGIONS:
        write(region, table, SOURCES / file, doc, lines, meta, names, stars)


REGIONS = [
    ("northern", NORTH, "NorthernSky.swift",
     "Kuzey göğü: the 22 constellations north of the celestial equator that the starter sky leaves out,\n"
     "    /// in unlock order. They open one by one once the starter sky is complete."),
    ("southern", SOUTH, "SouthernSky.swift",
     "Güney seferi: the 50 constellations south of the celestial equator, in unlock order. They open\n"
     "    /// one by one once Kuzey göğü is complete, ending at the south celestial pole."),
]


def write(region, table, out, doc, lines, meta, names, stars):
    blocks = []
    for d3id, cid, tr, latin, facts, look in table:
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
        if d3id == "Cen":
            labels = [star_name(names, hip, mag, genitive) if l != "Alnair" else star_name(
                {str(hip): {**names[str(hip)], "name": ""}}, hip, mag, genitive) for l, (hip, mag) in zip(labels, info)]
        clashing = [labels.count(l) > 1 for l in labels]
        labels = [star_name(names, hip, mag, genitive, numbered=True) if c else l
                  for l, c, (hip, mag) in zip(labels, clashing, info)]
        # Two stars that would still share a name (a catalogue quirk) fall back to their HD number.
        for i, (hip, _) in enumerate(info):
            if labels.count(labels[i]) > 1:
                labels[i] = (names.get(str(hip), {}).get("hd") or f"HIP {hip}").replace("\u2009", " ").strip()
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

    out.write_text(
        "// Generated by design/tools/make_sky_catalog.py from d3-celestial star data. Do not edit by hand.\n\n"
        "extension Catalog {\n"
        f"    /// {doc}\n"
        f"    public static let {region}: [Constellation] = [\n"
        + "\n".join(blocks).rstrip(",") + "\n"
        "    ]\n"
        "}\n"
    )
    print(f"wrote {out.relative_to(ROOT)}: {len(table)} constellations, "
          f"{sum(b.count('true)') + b.count('false)') for b in blocks)} stars")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "package/data")
