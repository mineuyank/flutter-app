import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D
from tensorflow.keras.models import Model

# 1. Verileri Yükleme ve Hazırlama
# Buradaki yol senin 'islenmis' klasörün olmalı
DATA_YOLU = "C:/ev_bitkileri_islenmis"

datagen = ImageDataGenerator(rescale=1./255, validation_split=0.2)

train_data = datagen.flow_from_directory(
    DATA_YOLU, target_size=(224, 224), batch_size=32,
    class_mode='binary', subset='training')

val_data = datagen.flow_from_directory(
    DATA_YOLU, target_size=(224, 224), batch_size=32,
    class_mode='binary', subset='validation')

# 2. MobileNetV2 Modelini Kurma
base_model = MobileNetV2(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dense(128, activation='relu')(x)
output = Dense(1, activation='sigmoid')(x) # Sağlıklı mı Stresli mi? (0 veya 1)

model = Model(inputs=base_model.input, outputs=output)

# Sadece bizim eklediğimiz son katmanları eğit diyoruz (Transfer Learning)
for layer in base_model.layers:
    layer.trainable = False

# 3. Modeli Derleme ve Eğitme
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

print("Eğitim başlıyor... Bu biraz vakit alabilir.")
model.fit(train_data, validation_data=val_data, epochs=5)

# 4. Modeli Kaydet
model.save("ev_bitkisi_modeli.h5")
print("Tebrikler! Modelin 'ev_bitkisi_modeli.h5' adıyla kaydedildi.")