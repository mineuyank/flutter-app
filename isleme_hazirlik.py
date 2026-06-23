import cv2
import os
import albumentations as A
import numpy as np

# Klasör yolların (Kendi yollarına göre kontrol et)
KAYNAK_DIZIN = "C:/ev_bitkileri_data"
HEDEF_DIZIN = "C:/ev_bitkileri_islenmis"

# 1. Veri Zenginleştirme Kuralları (Augmentation)
# Resmi çeviriyoruz, parlaklığını değiştiriyoruz ki model her koşulda tanısın
transform = A.Compose([
    A.Resize(width=224, height=224), # Boyutu sabitle
    A.HorizontalFlip(p=0.5),         # Rastgele sağ-sol çevir
    A.RandomBrightnessContrast(p=0.2),# Işığı değiştir
    A.Rotate(limit=30, p=0.5)        # 30 dereceye kadar döndür
])

def verileri_hazirla():
    if not os.path.exists(HEDEF_DIZIN):
        os.makedirs(HEDEF_DIZIN)
        
    for kategori in ["Saglikli", "Stresli"]:
        kat_yolu = os.path.join(KAYNAK_DIZIN, kategori)
        hedef_kat_yolu = os.path.join(HEDEF_DIZIN, kategori)
        
        if not os.path.exists(hedef_kat_yolu):
            os.makedirs(hedef_kat_yolu)
            
        print(f"{kategori} kategorisi işleniyor...")
        
        for alt_klasor in os.listdir(kat_yolu):
            alt_yol = os.path.join(kat_yolu, alt_klasor)
            if os.path.isdir(alt_yol):
                for dosya in os.listdir(alt_yol):
                    resim_yolu = os.path.join(alt_yol, dosya)
                    resim = cv2.imread(resim_yolu)
                    
                    if resim is not None:
                        # İşleme (Resize ve Augmentation)
                        transformed = transform(image=resim)
                        islenmis_resim = transformed["image"]
                        
                        # Kaydet
                        yeni_ad = f"islenmis_{dosya}"
                        cv2.imwrite(os.path.join(hedef_kat_yolu, yeni_ad), islenmis_resim)

if __name__ == "__main__":
    verileri_hazirla()
    print("İşlem tamam! Artık tertemiz ve standart boyutlarda bir veri setin var.")