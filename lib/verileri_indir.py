from bing_image_downloader import downloader
import os

# Verilerin kaydedileceği ana klasör
ana_dizin = "C:/ev_bitkileri_data"

# İndirmek istediğin ev bitkilerini ve durumlarını buraya yazıyoruz
# Projenin "Sağlıklı" ve "Stresli" sınıfları için anahtar kelimeler
bitki_listesi = {
    "Saglikli": [
        "healthy monstera deliciosa leaf",
        "healthy aloe vera plant",
        "healthy snake plant leaves",
        "healthy peace lily plant"
        "healthy pothos ivy hanging",
        "healthy spider plant indoor"
    ],
    "Stresli": [
       "yellow monstera leaf brown spots", # Güneş yanığı veya besin eksikliği
        "wilted drooping peace lily",       # Susuzluk (en net stres göstergesi)
        "root rot snake plant base",        # Fazla sulama
        "spider plant brown tips",          # Düşük nem stresi
        "aloe vera mushy brown leaves",     # Fazla sulama/çürüme
        "pothos yellow leaves drooping"     # Genel stres/bakımsızlık
    ]
}

def veri_topla():
    for kategori, anahtar_kelimeler in bitki_listesi.items():
        for kelime in anahtar_kelimeler:
            print(f"Şu an indiriliyor: {kelime} ({kategori} kategorisi)")
            downloader.download(
                kelime, 
                limit=50,  # Denemek için her kelimeden 50 tane. Sonra 200 yapabilirsin.
                output_dir=os.path.join(ana_dizin, kategori), 
                adult_filter_off=True, 
                force_replace=False, 
                timeout=60
            )

if __name__ == "__main__":
    veri_topla()
    print(f"İşlem tamam! Görseller şurada: {ana_dizin}")