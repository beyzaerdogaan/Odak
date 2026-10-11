import Foundation

/// A star the user can light. Coordinates are in the constellation's own drawing space;
/// views scale them to fit, so only the relative layout matters.
public struct CatalogStar: Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let x: Double
    public let y: Double
    /// Brighter stars are drawn larger. 1 = faint, 3 = brightest.
    public let size: Double
    /// Bright stars only drop in sessions of 60+ minutes, in strict mode, or with a ticket.
    public let isBright: Bool
}

public struct Constellation: Hashable, Identifiable, Sendable {
    public struct Line: Hashable, Sendable {
        public let from: String
        public let to: String
    }

    public let id: String
    public let name: String
    public let latin: String
    public let stars: [CatalogStar]
    public let lines: [Line]
    public let facts: [String]
    public let whereToLook: String
    /// Sound pack the completion unlocks, if any.
    public let unlocksSound: SoundID?

    public var tier: Int { (Catalog.constellations.firstIndex(of: self) ?? 0) / 4 + 1 }
    public func star(_ id: String) -> CatalogStar? { stars.first { $0.id == id } }
}

/// Short builder so the catalogue below reads like a star chart.
private func c(_ id: String, _ name: String, _ latin: String,
               stars: [(String, Double, Double, Double, Bool)],
               lines: [(String, String)], facts: [String], look: String,
               sound: SoundID? = nil) -> Constellation {
    func key(_ star: String) -> String {
        "\(id)." + star.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
    }
    return Constellation(
        id: id, name: name, latin: latin,
        stars: stars.map { CatalogStar(id: key($0.0), name: $0.0, x: $0.1, y: $0.2, size: $0.3, isBright: $0.4) },
        lines: lines.map { Constellation.Line(from: key($0.0), to: key($0.1)) },
        facts: facts, whereToLook: look, unlocksSound: sound)
}

public enum Catalog {
    /// The 16-constellation starter sky, in unlock order (four tiers of four, easy to hard).
    /// Facts must be checked against an astronomy source before release.
    public static let constellations: [Constellation] = [
        c("ursa-major", "Büyük Ayı", "Ursa Major",
          stars: [("Dubhe", 80, 20, 2.4, false), ("Merak", 80, 45, 2, false), ("Phecda", 55, 52, 2, false),
                  ("Megrez", 52, 32, 1.4, false), ("Alioth", 35, 30, 2.4, false), ("Mizar", 20, 28, 2.2, false),
                  ("Alkaid", 0, 40, 2.2, false)],
          lines: [("Dubhe", "Merak"), ("Merak", "Phecda"), ("Phecda", "Megrez"), ("Megrez", "Dubhe"),
                  ("Megrez", "Alioth"), ("Alioth", "Mizar"), ("Mizar", "Alkaid")],
          facts: ["En parlak yedi yıldızı “Büyük Kepçe” olarak bilinir.",
                  "Merak'tan Dubhe'ye giden çizgiyi yaklaşık beş kat uzatırsan Kutup Yıldızı'na varırsın.",
                  "Mizar'ın hemen yanında sönük Alcor durur. İkisini ayırt etmek eskiden bir göz testiydi."],
          look: "Türkiye'den yıl boyunca kuzeyde görülür, en iyi bahar akşamları."),
        c("orion", "Avcı", "Orion",
          stars: [("Betelgeuse", 112, 22, 3, true), ("Bellatrix", 214, 30, 2, false), ("Alnitak", 150, 92, 1.8, false),
                  ("Alnilam", 170, 88, 1.9, false), ("Mintaka", 190, 84, 1.8, false), ("Saiph", 126, 152, 2, false),
                  ("Rigel", 226, 146, 3, true)],
          lines: [("Betelgeuse", "Bellatrix"), ("Betelgeuse", "Alnitak"), ("Bellatrix", "Mintaka"), ("Alnitak", "Alnilam"),
                  ("Alnilam", "Mintaka"), ("Alnitak", "Saiph"), ("Mintaka", "Rigel")],
          facts: ["Ortadaki üç yıldız “Avcı'nın Kemeri”. Gökyüzünde en kolay bulunan dizilimlerden biri.",
                  "Betelgeuse turuncu-kırmızı bir süperdev. Rigel ise mavi-beyaz ve takımyıldızın en parlak yıldızı.",
                  "Türkiye'den kış akşamları güney gökyüzünde çıplak gözle görülür."],
          look: "Kış akşamları güneye bak. Önce kemerdeki üç yıldızı bul.", sound: .winterNight),
        c("cassiopeia", "Kassiopeia", "Cassiopeia",
          stars: [("Caph", 0, 10, 2, false), ("Schedar", 15, 30, 2.2, false), ("Navi", 30, 15, 2.2, false),
                  ("Ruchbah", 45, 28, 1.8, false), ("Segin", 60, 8, 1.4, false)],
          lines: [("Caph", "Schedar"), ("Schedar", "Navi"), ("Navi", "Ruchbah"), ("Ruchbah", "Segin")],
          facts: ["Gökyüzünde belirgin bir W ya da M harfi çizer.",
                  "Kutup Yıldızı'nın Büyük Ayı'ya göre tam karşı tarafında durur.",
                  "Adını mitolojideki güzelliğiyle övünen kraliçeden alır."],
          look: "Yıl boyunca kuzeyde, en iyi sonbahar akşamları."),
        c("cygnus", "Kuğu", "Cygnus",
          stars: [("Deneb", 50, 0, 3, true), ("Sadr", 50, 35, 2.2, false), ("Gienah", 80, 48, 2, false),
                  ("Fawaris", 20, 25, 1.8, false), ("Albireo", 50, 92, 1.8, false), ("Eta Cygni", 50, 62, 1.2, false),
                  ("Zeta Cygni", 95, 64, 1.4, false), ("Iota Cygni", 6, 12, 1.2, false), ("Kappa Cygni", 0, 0, 1.2, false)],
          lines: [("Deneb", "Sadr"), ("Sadr", "Eta Cygni"), ("Eta Cygni", "Albireo"), ("Fawaris", "Sadr"),
                  ("Sadr", "Gienah"), ("Gienah", "Zeta Cygni"), ("Fawaris", "Iota Cygni"), ("Iota Cygni", "Kappa Cygni")],
          facts: ["Deneb; Vega ve Altair ile birlikte “Yaz Üçgeni”ni oluşturur.",
                  "Samanyolu'nun tam üzerinde uzanır, “Kuzey Haçı” olarak da bilinir.",
                  "Albireo küçük bir teleskopla altın ve mavi iki yıldıza ayrılır."],
          look: "Yaz ve sonbahar akşamları başucuna yakın."),
        c("ursa-minor", "Küçük Ayı", "Ursa Minor",
          stars: [("Polaris", 0, 0, 2.4, false), ("Yildun", 12, 8, 1.2, false), ("Epsilon UMi", 22, 18, 1.2, false),
                  ("Akhfa", 32, 30, 1.4, false), ("Eta UMi", 42, 42, 1.2, false), ("Pherkad", 56, 36, 1.8, false),
                  ("Kochab", 48, 24, 2.2, false)],
          lines: [("Polaris", "Yildun"), ("Yildun", "Epsilon UMi"), ("Epsilon UMi", "Akhfa"), ("Akhfa", "Eta UMi"),
                  ("Eta UMi", "Pherkad"), ("Pherkad", "Kochab"), ("Kochab", "Akhfa")],
          facts: ["Kuyruğunun ucundaki yıldız Polaris, yani Kutup Yıldızı.",
                  "Polaris kuzey gök kutbuna çok yakın olduğu için gece boyunca neredeyse hiç yer değiştirmez.",
                  "Kochab ve Pherkad “kutbun bekçileri” diye anılır."],
          look: "Yıl boyunca tam kuzeyde. Şehir ışığında sönük yıldızları zor seçilir."),
        c("lyra", "Lir", "Lyra",
          stars: [("Vega", 10, 5, 3, true), ("Epsilon Lyrae", 28, 0, 1.2, false), ("Zeta Lyrae", 30, 25, 1.4, false),
                  ("Delta Lyrae", 50, 30, 1.2, false), ("Sulafat", 55, 62, 1.8, false), ("Sheliak", 35, 58, 1.8, false)],
          lines: [("Vega", "Epsilon Lyrae"), ("Vega", "Zeta Lyrae"), ("Epsilon Lyrae", "Zeta Lyrae"), ("Zeta Lyrae", "Delta Lyrae"),
                  ("Delta Lyrae", "Sulafat"), ("Sulafat", "Sheliak"), ("Sheliak", "Zeta Lyrae")],
          facts: ["Vega gece gökyüzünün en parlak yıldızlarından biri.",
                  "Lir, mitolojide Orpheus'un çalgısını temsil eder.",
                  "Dünya'nın ekseni yavaşça yalpaladığı için binlerce yıl sonra Vega kutup yıldızı olacak."],
          look: "Yaz akşamları başucunda, mavi-beyaz Vega'yı ara."),
        c("leo", "Aslan", "Leo",
          stars: [("Regulus", 80, 70, 2.4, false), ("Algieba", 75, 35, 2.2, false), ("Adhafera", 78, 20, 1.4, false),
                  ("Ras Elased", 90, 8, 1.6, false), ("Zosma", 35, 38, 2, false), ("Chertan", 38, 62, 1.8, false),
                  ("Denebola", 0, 60, 2.2, false)],
          lines: [("Regulus", "Algieba"), ("Algieba", "Adhafera"), ("Adhafera", "Ras Elased"), ("Algieba", "Zosma"),
                  ("Zosma", "Denebola"), ("Denebola", "Chertan"), ("Chertan", "Regulus"), ("Chertan", "Zosma")],
          facts: ["Regulus ekliptiğe çok yakın; Ay sık sık önünden geçer.",
                  "Aslan'ın başı ters bir soru işaretine benzer, buna “Orak” denir.",
                  "Kasımdaki Leonid meteor yağmuru bu yönden geliyor gibi görünür."],
          look: "Bahar akşamları güneyde, yüksekte."),
        c("scorpius", "Akrep", "Scorpius",
          stars: [("Acrab", 85, 0, 1.8, false), ("Dschubba", 82, 14, 2, false), ("Fang", 80, 30, 1.6, false),
                  ("Antares", 62, 22, 3, true), ("Paikauhale", 55, 35, 1.6, false), ("Larawag", 48, 55, 1.8, false),
                  ("Sargas", 30, 85, 2, false), ("Shaula", 8, 70, 2.2, false), ("Lesath", 14, 66, 1.4, false)],
          lines: [("Acrab", "Dschubba"), ("Dschubba", "Fang"), ("Dschubba", "Antares"), ("Antares", "Paikauhale"),
                  ("Paikauhale", "Larawag"), ("Larawag", "Sargas"), ("Sargas", "Shaula"), ("Shaula", "Lesath")],
          facts: ["Antares'in adı “Mars'ın rakibi” anlamına gelir; kırmızı rengi Mars'a benzer.",
                  "Antares bir kırmızı süperdev, Güneş'ten yüzlerce kat büyük.",
                  "Kuyruğu Türkiye'den güney ufkunun hemen üstünde, alçakta görünür."],
          look: "Yaz akşamları güney ufkunun hemen üstünde."),
        c("gemini", "İkizler", "Gemini",
          stars: [("Castor", 10, 0, 2.4, false), ("Pollux", 32, 6, 3, true), ("Mebsuta", 8, 40, 1.6, false),
                  ("Tejat", 4, 62, 1.6, false), ("Propus", 0, 74, 1.4, false), ("Wasat", 38, 42, 1.6, false),
                  ("Alhena", 30, 80, 2.2, false), ("Alzirr", 52, 70, 1.4, false)],
          lines: [("Castor", "Pollux"), ("Castor", "Mebsuta"), ("Mebsuta", "Tejat"), ("Tejat", "Propus"),
                  ("Pollux", "Wasat"), ("Wasat", "Alhena"), ("Wasat", "Alzirr")],
          facts: ["Castor ve Pollux mitolojideki ikiz kardeşler.",
                  "Pollux, Castor'dan biraz daha parlaktır ve turuncumsu görünür.",
                  "Aralıktaki Geminid meteor yağmuru bu yönden geliyor gibi görünür."],
          look: "Kış akşamları, Avcı'nın kuzeydoğusunda yüksekte."),
        c("taurus", "Boğa", "Taurus",
          stars: [("Aldebaran", 42, 52, 3, true), ("Ain", 40, 35, 1.6, false), ("Prima Hyadum", 30, 45, 1.6, false),
                  ("Elnath", 80, 0, 2.2, false), ("Tianguan", 85, 55, 1.8, false), ("Alcyone", 0, 15, 1.6, false),
                  ("Lambda Tauri", 18, 60, 1.4, false)],
          lines: [("Prima Hyadum", "Aldebaran"), ("Aldebaran", "Tianguan"), ("Prima Hyadum", "Ain"), ("Ain", "Elnath"),
                  ("Prima Hyadum", "Lambda Tauri"), ("Ain", "Alcyone")],
          facts: ["Aldebaran, Boğa'nın kırmızımsı gözü.",
                  "Ülker (Yedi Kız Kardeş) yıldız kümesi Boğa'nın sırtında durur.",
                  "Aldebaran'ın çevresindeki V şekli Hyadlar kümesi; Aldebaran ise onun önünde, bize daha yakın."],
          look: "Kış akşamları, Avcı'nın kemerinden sağa yukarı doğru uzan."),
        c("aquila", "Kartal", "Aquila",
          stars: [("Altair", 50, 40, 3, true), ("Tarazed", 55, 30, 1.8, false), ("Alshain", 45, 50, 1.6, false),
                  ("Okab", 70, 10, 1.6, false), ("Delta Aquilae", 30, 55, 1.4, false), ("Al Thalimain", 10, 75, 1.4, false)],
          lines: [("Tarazed", "Altair"), ("Altair", "Alshain"), ("Tarazed", "Okab"), ("Altair", "Delta Aquilae"),
                  ("Delta Aquilae", "Al Thalimain")],
          facts: ["Altair, Yaz Üçgeni'nin üç yıldızından biri.",
                  "Altair çok hızlı döndüğü için ekvatoru belirgin şekilde şişkindir.",
                  "Samanyolu'nun parlak bir bölgesinin kenarında durur."],
          look: "Yaz akşamları güneyde, Kuğu'nun altında."),
        c("perseus", "Perseus", "Perseus",
          stars: [("Mirfak", 40, 30, 2.4, false), ("Algol", 30, 60, 2.2, false), ("Miram", 48, 0, 1.4, false),
                  ("Delta Persei", 50, 45, 1.6, false), ("Epsilon Persei", 55, 70, 1.6, false), ("Menkib", 58, 88, 1.4, false),
                  ("Atik", 68, 94, 1.8, false)],
          lines: [("Miram", "Mirfak"), ("Mirfak", "Delta Persei"), ("Delta Persei", "Epsilon Persei"),
                  ("Epsilon Persei", "Menkib"), ("Menkib", "Atik"), ("Mirfak", "Algol")],
          facts: ["Algol'ün parlaklığı yaklaşık üç günde bir belirgin şekilde düşer; yörüngedeki eşi önünden geçer.",
                  "Ağustostaki Perseid meteor yağmuru bu yönden geliyor gibi görünür.",
                  "Mitolojide Medusa'yı yenen kahramanı temsil eder."],
          look: "Sonbahar ve kış akşamları kuzeydoğuda."),
        c("andromeda", "Andromeda", "Andromeda",
          stars: [("Alpheratz", 0, 30, 2.4, false), ("Delta Andromedae", 20, 30, 1.6, false), ("Mirach", 45, 35, 2.4, false),
                  ("Almach", 80, 30, 2.2, false), ("Pi Andromedae", 30, 10, 1.2, false)],
          lines: [("Alpheratz", "Delta Andromedae"), ("Delta Andromedae", "Mirach"), ("Mirach", "Almach"),
                  ("Delta Andromedae", "Pi Andromedae")],
          facts: ["Çıplak gözle görülebilen en uzak nesnelerden biri, Andromeda Galaksisi bu takımyıldızda.",
                  "Alpheratz, Pegasus'un Büyük Karesi'nin bir köşesini de oluşturur.",
                  "Almach küçük bir teleskopla turuncu ve mavi iki yıldıza ayrılır."],
          look: "Sonbahar akşamları başucuna yakın."),
        c("pegasus", "Pegasus", "Pegasus",
          stars: [("Markab", 60, 60, 2.2, false), ("Scheat", 62, 20, 2.2, false), ("Algenib", 100, 62, 2, false),
                  ("Homam", 35, 55, 1.6, false), ("Biham", 20, 50, 1.4, false), ("Enif", 0, 40, 2.2, false),
                  ("Matar", 40, 5, 1.6, false)],
          lines: [("Markab", "Scheat"), ("Markab", "Algenib"), ("Markab", "Homam"), ("Homam", "Biham"),
                  ("Biham", "Enif"), ("Scheat", "Matar")],
          facts: ["Dört yıldız “Pegasus'un Büyük Karesi”ni oluşturur; biri aslında Andromeda'nın Alpheratz'ı.",
                  "Enif kanatlı atın burnunu temsil eder.",
                  "Karenin içi çıplak gözle bakınca şaşırtıcı derecede boş görünür."],
          look: "Sonbahar akşamları güneyde, yüksekte."),
        c("sagittarius", "Yay", "Sagittarius",
          stars: [("Kaus Australis", 30, 70, 2.4, false), ("Kaus Media", 28, 50, 1.8, false), ("Kaus Borealis", 35, 30, 1.8, false),
                  ("Alnasl", 5, 55, 1.8, false), ("Nunki", 70, 35, 2.2, false), ("Ascella", 65, 65, 2, false),
                  ("Phi Sagittarii", 50, 45, 1.4, false), ("Tau Sagittarii", 85, 55, 1.4, false)],
          lines: [("Alnasl", "Kaus Media"), ("Kaus Media", "Kaus Australis"), ("Kaus Australis", "Alnasl"),
                  ("Kaus Media", "Kaus Borealis"), ("Kaus Borealis", "Phi Sagittarii"), ("Phi Sagittarii", "Kaus Media"),
                  ("Phi Sagittarii", "Nunki"), ("Nunki", "Tau Sagittarii"), ("Tau Sagittarii", "Ascella"),
                  ("Ascella", "Phi Sagittarii"), ("Ascella", "Kaus Australis")],
          facts: ["Ana yıldızları bir çaydanlığa benzer.",
                  "Samanyolu'nun merkezi bu yönde; çaydanlığın ağzından buhar yükseliyor gibi görünür.",
                  "Pek çok bulutsu ve yıldız kümesi bu bölgede toplanır."],
          look: "Yaz akşamları güney ufkunun üstünde, Akrep'in solunda."),
        c("bootes", "Çoban", "Boötes",
          stars: [("Arcturus", 40, 90, 3, true), ("Izar", 55, 65, 1.8, false), ("Muphrid", 25, 82, 1.6, false),
                  ("Seginus", 30, 30, 1.6, false), ("Nekkar", 45, 5, 1.4, false), ("Princeps", 62, 35, 1.4, false),
                  ("Rho Bootis", 35, 62, 1.2, false)],
          lines: [("Arcturus", "Izar"), ("Izar", "Princeps"), ("Princeps", "Nekkar"), ("Nekkar", "Seginus"),
                  ("Seginus", "Rho Bootis"), ("Rho Bootis", "Arcturus"), ("Arcturus", "Muphrid")],
          facts: ["Arcturus, kuzey gökyüzünün en parlak yıldızı.",
                  "Büyük Ayı'nın kuyruğundaki kavisi takip edersen Arcturus'a varırsın.",
                  "Arcturus turuncu bir dev yıldız."],
          look: "Bahar ve yaz akşamları, Büyük Ayı'nın kuyruğunun ucundan aşağı."),
    ]

    public static func constellation(_ id: String) -> Constellation? { constellations.first { $0.id == id } }

    /// Number of constellations in the whole sky; layer 2 opens the remaining ones in a later release.
    public static let officialConstellationCount = 88

    public static func constellation(containing starID: String) -> Constellation? {
        constellations.first { $0.star(starID) != nil }
    }
}
