# VozGuia — App Flutter

Aplicativo Android de navegação indoor por voz para pessoas com deficiência visual. Utiliza YOLOv8 via TFLite para detecção de objetos em tempo real e síntese de voz em português brasileiro.

Parte do TCC — Ciência da Computação | Universidade Tiradentes (UNIT).

---

## Pré-requisitos

- [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado e no PATH
- [Android Studio](https://developer.android.com/studio) com JDK embutido (Java 21)
- Android SDK — API 36, NDK `28.2.13676358`
- Celular Android com **Depuração USB** ativada (`minSdk 24` — Android 7.0+)
- Modelos TFLite em `android/app/src/main/assets/` (veja abaixo)

---

## Preparar os modelos

Os modelos não estão versionados no repositório. Na raiz do projeto execute:

```bash
python setup_modelos.py
```

Isso baixa `best_int8.tflite` e `best_float16.tflite` do GitHub Release e os copia automaticamente para `android/app/src/main/assets/`.

---

## Como compilar

```bash
cd app_mobile

# Instalar dependências
flutter pub get

# Compilar APK de release
JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" flutter build apk --release
```

O APK gerado estará em:

```
build/app/outputs/flutter-apk/app-release.apk
```

> **Nota:** `JAVA_HOME` precisa apontar para o JDK do Android Studio porque o pacote `ultralytics_yolo` requer Java 17+.

Para instalar em celulares Xiaomi (Redmi) que bloqueiam instalação via USB, transfira o APK pelo modo **Transferência de arquivo (MTP)** e instale manualmente.

---

## Estrutura

```
lib/
├── main.dart                      # Ponto de entrada — gerencia permissão de câmera
├── detector/
│   └── object_detector.dart       # Classe Detection (dados de cada objeto detectado)
├── tts/
│   └── tts_service.dart           # Lógica de avisos de voz: prioridade, proximidade e posição
└── screens/
    └── camera_screen.dart         # UI: YOLOView + overlay de bounding boxes + barra de status

android/app/src/main/assets/
├── best_float16.tflite            # Modelo padrão em uso (float16, ~6 MB, 256×256)
└── best_int8.tflite               # Alternativa quantizada (int8, ~3 MB, 256×256)
```

---

## Funcionalidades

- Detecção em tempo real via câmera traseira com aceleração GPU (TFLite nativo via `ultralytics_yolo`)
- Indicador de hardware (**GPU** ou **CPU**) e **FPS** na barra de status
- Sistema de prioridade de anúncio: Pessoa (alta) → pontos de navegação (média) → referências (baixa)
- Posição espacial: *à sua esquerda*, *à sua frente* ou *à sua direita*
- Alerta de proximidade: *próximo* (>15% do frame) e *muito próximo* (>30%)
- Buffer de confirmação: objeto precisa ser visível por tempo mínimo antes do primeiro aviso
- Reaviso periódico para objetos que continuam no campo de visão
- Concordância de gênero gramatical nos anúncios em português brasileiro
- Síntese de voz em português brasileiro via `flutter_tts` (Android TTS nativo)

---

## Trocar o modelo

O modelo ativo é definido em [lib/screens/camera_screen.dart](lib/screens/camera_screen.dart):

```dart
YOLOView(
  modelPath: 'best_float16',   // ou 'best_int8' para menor uso de memória
  ...
)
```

---

## Trabalhos Futuros

- **Leitura de número de sala via OCR:** Integrar o ML Kit Text Recognition para, após detectar uma placa de sala, anunciar o número por voz.
- **Novas classes de objetos:** `stairs`, `bench`, `drinking fountain` para maior cobertura de obstáculos universitários.
- **Modo de baixo consumo:** Redução dinâmica da frequência de inferência conforme nível de bateria.
- **Feedback tátil:** Vibração combinada com os avisos de voz para usuários com deficiência auditiva concomitante.
