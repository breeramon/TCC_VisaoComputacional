# VozGuia: Aplicativo Flutter de Identificação de Obstáculos Baseado em Visão Computacional Para Pessoas com Deficiência Visual

**TCC — Ciência da Computação | Universidade Tiradentes (UNIT)**

Autor: Breno Ramon Santana dos Santos

Orientador: Prof. Felipe dos Anjos

---

## Sobre o Projeto

Aplicativo Android baseado em Inteligência Artificial para auxiliar pessoas cegas e pessoas com baixa visão a se locomover de forma autônoma em ambientes internos. O sistema utiliza a câmera do smartphone para capturar o ambiente em tempo real, detecta objetos relevantes à navegação com YOLOv8 e fornece instruções de voz em português brasileiro.

O estudo de caso vai ser realizado no campus Farolândia da Universidade Tiradentes, em Aracaju/SE.

---

## Tecnologias Utilizadas

| Componente | Tecnologia |
|---|---|
| Linguagem (scripts IA) | Python 3.x |
| Detecção de objetos | YOLOv8s (Ultralytics) |
| Inferência no Android | ultralytics_yolo (nativo C++, GPU via TFLite) |
| Síntese de voz (app) | flutter_tts (Android TTS nativo) |
| Síntese de voz (protótipo PC) | Windows TTS via subprocess |
| App mobile | Flutter (Android) |
| Exportação do modelo | TensorFlow Lite — int8 e float16 |

---

## Classes de Objetos Detectados

O modelo detecta 17 classes. Os nomes abaixo são os identificadores internos do modelo (inglês) seguidos do que é anunciado em voz pelo app (português):

| Classe no modelo | Anúncio em voz | Prioridade |
|---|---|---|
| `person` | Pessoa | Alta |
| `door` | Porta | Média |
| `elevator` | Elevador | Média |
| `elevator sign` | Placa de elevador | Média |
| `stair sign` | Placa de escada | Média |
| `exit sign` | Sinalização de saída | Média |
| `fire alarm` | Alarme de incêndio | Média |
| `fire extinguisher` | Extintor de incêndio | Baixa |
| `trash can` | Lixeira | Baixa |
| `water dispenser` | Bebedouro | Baixa |
| `handle` | Maçaneta | Baixa |
| `push handle` | Maçaneta de empurrar | Baixa |
| `men-s washroom` | Banheiro masculino | Baixa |
| `women-s washroom` | Banheiro feminino | Baixa |
| `accessibility` | Acessibilidade | Baixa |

---

## Datasets Utilizados no Treinamento

- **indoor-navigation Computer Vision Dataset** — [Roboflow Universe](https://universe.roboflow.com/akhash/indoor-navigation-xs4of)
- Outro dataset em pesquisa.

---

## Estrutura do Projeto

```
TCC_VisaoComputacional/
│
├── scriptsIA/
│   ├── 01_testeCamera.py          # Diagnóstico da câmera
│   ├── 02_reconhecimentoYolo.py   # Visualização das detecções com FPS
│   ├── 03_treinamento_yolo.py     # Fine-tuning do YOLOv8
│   ├── 04_assistente_completo.py  # Assistente de voz com reconhecimento em tempo real
│   └── 05_exportar_tflite.py      # Exportação int8 e float16 para Android (256×256)
│
├── dados/
│   ├── brutos/                    # Imagens coletadas na UNIT (ignoradas pelo .gitignore)
│   └── anotados/                  # Dataset rotulado para treino (ignorado pelo .gitignore)
│
├── runs/                          # Resultados dos treinamentos (pesos, métricas, gráficos)
│   └── detect/modelos/
│       └── treino_tcc_v20260429_0902/  # Melhor modelo treinado (mAP50: 76.6%)
│
├── exports/                       # Modelos exportados (ignorados pelo .gitignore)
│   ├── best_int8.tflite           # Quantizado int8, 256×256 (~11 MB) — uso no app
│   └── best_float16.tflite        # Float16, 256×256 (~21 MB) — fallback de precisão
│
├── app_mobile/                    # Aplicativo Flutter para Android
├── requirements.txt               # Dependências Python
└── .gitignore
```

---

## Como Executar o Protótipo (PC)

### 1. Instalar dependências

```bash
cd TCC_VisaoComputacional
python -m venv .venv
source .venv/Scripts/activate   # Windows
pip install -r requirements.txt
```

### 2. Testar a câmera

```bash
python scriptsIA/01_testeCamera.py
```

### 3. Rodar o reconhecimento visual

```bash
python scriptsIA/02_reconhecimentoYolo.py
```

### 4. Rodar o assistente de voz completo

```bash
python scriptsIA/04_assistente_completo.py
```

### 5. Exportar o modelo para Android

```bash
python scriptsIA/05_exportar_tflite.py
```

O script gera automaticamente os dois formatos (int8 e float16) e os copia para `app_mobile/android/app/src/main/assets/`.

> **Nota:** Os scripts de PC utilizam o [Iriun Webcam](https://iriun.com/) para espelhar a câmera do celular Android no computador durante o desenvolvimento.

---

## Modelo Treinado

O modelo atual (`treino_tcc_v20260429_0902`) foi treinado com fine-tuning sobre o YOLOv8n com as seguintes métricas:

| Métrica | Valor |
|---|---|
| mAP50 | 76.6% |
| mAP50-95 | 55.4% |
| Precisão | 82.1% |
| Recall | 71.7% |
| Épocas | 90 (early stopping — melhor resultado no epoch 70) |

### Métricas por classe

| Classe | Precisão | Recall | mAP50 | mAP50-95 |
|---|---|---|---|---|
| `acessibility` | 69.3% | 66.0% | 66.9% | 42.5% |
| `door` | 79.6% | 80.9% | 85.9% | 70.6% |
| `elevator` | 89.9% | 90.0% | 94.1% | 75.2% |
| `elevator sign` | 84.5% | 28.4% | 40.3% | 21.9% |
| `exit sign` | 75.8% | 79.5% | 82.2% | 51.2% |
| `fire alarm` | 77.9% | 60.0% | 67.1% | 38.3% |
| `fire extinguisher` | 93.3% | 86.3% | 91.9% | 70.8% |
| `handle` | 78.2% | 61.6% | 74.1% | 36.1% |
| `men washroom` | 82.9% | 87.4% | 79.1% | 55.5% |
| `person` | 84.0% | 76.7% | 84.4% | 58.2% |
| `push handle` | 77.9% | 62.0% | 71.1% | 45.8% |
| `stair sign` | 71.7% | 44.0% | 52.5% | 42.2% |
| `trash can` | 84.6% | 75.4% | 81.0% | 62.2% |
| `water dispenser` | 88.4% | 86.7% | 87.7% | 83.1% |
| `women washrooom` | 92.8% | 90.0% | 91.4% | 76.7% |

> Classes com mAP50 abaixo de 60% (`elevator sign` e `stair sign`) possuem poucas imagens de validação e são candidatas a melhoria com coleta adicional de dados.

### Formatos exportados

| Arquivo | Formato | Tamanho | Resolução | Uso |
|---|---|---|---|---|
| `best_int8.tflite` | Int8 quantizado | ~3 MB | 256×256 | App (padrão) |
| `best_float16.tflite` | Float16 | ~6 MB | 256×256 | Fallback de precisão |

Os arquivos `.tflite` e o `.pt` não estão versionados no repositório. Há duas formas de obtê-los:

**Opção 1 — Baixar do GitHub Release (recomendado):**

```bash
python setup_modelos.py
```

O script baixa automaticamente `best_int8.tflite`, `best_float16.tflite` e `best.pt` da release mais recente e os coloca nas pastas corretas (`exports/` e `app_mobile/android/app/src/main/assets/`).

**Opção 2 — Gerar a partir do modelo treinado:**

```bash
python scriptsIA/05_exportar_tflite.py runs/detect/modelos/treino_tcc_v20260429_0902/weights/best.pt
```

Requer o arquivo `best.pt` disponível localmente em `runs/detect/modelos/treino_tcc_v20260429_0902/weights/`.

---

## App Android (Flutter)

O aplicativo mobile foi desenvolvido em Flutter para Android, utilizando o pacote `ultralytics_yolo` para inferência nativa com aceleração GPU.

### Estrutura do App

```
app_mobile/
├── lib/
│   ├── main.dart                      # Ponto de entrada — gerencia permissão de câmera
│   ├── detector/
│   │   └── object_detector.dart       # Classe Detection (dados de cada objeto detectado)
│   ├── tts/
│   │   └── tts_service.dart           # Lógica de avisos de voz: prioridade, proximidade e posição
│   └── screens/
│       └── camera_screen.dart         # UI: YOLOView + overlay de bounding boxes + barra de status
│
└── android/
    └── app/
        ├── build.gradle.kts           # Configurações de compilação (NDK 28, Java 17, minSdk 24)
        ├── proguard-rules.pro         # Regras R8 para LiteRT e snakeyaml
        └── src/main/
            ├── AndroidManifest.xml
            └── assets/
                ├── best_int8.tflite       # Modelo padrão (copiar de exports/)
                └── best_float16.tflite    # Modelo alternativo (copiar de exports/)
```

### Pré-requisitos

- [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado e no PATH
- [Android Studio](https://developer.android.com/studio) com JDK embutido (Java 21)
- Android SDK — API 36, NDK `28.2.13676358`
- Celular Android com **Depuração USB** ativada e `minSdk 24` (Android 7.0+)
- Modelos exportados em `app_mobile/android/app/src/main/assets/` (gerados por `05_exportar_tflite.py`)

> O comando de build exige `JAVA_HOME` apontando para o JDK do Android Studio porque o pacote `ultralytics_yolo` requer Java 17+.

### Como Compilar e Instalar

```bash
cd app_mobile

# Instalar dependências Flutter
flutter pub get

# Compilar APK de release
JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" flutter build apk --release

# O APK gerado estará em:
# build/app/outputs/flutter-apk/app-release.apk
```

Para instalar em celulares Xiaomi (Redmi) que bloqueiam instalação via USB, transfira o APK pelo modo **Transferência de arquivo (MTP)** e instale manualmente.

### Funcionalidades do App

- Detecção de objetos em tempo real via câmera traseira (inferência nativa com GPU)
- Indicador de hardware na tela: **GPU** ou **CPU** e contagem de **FPS**
- Sistema de prioridade de anúncio: Pessoa (alta) → pontos de navegação (média) → referências (baixa)
- Posição espacial do objeto: *à sua esquerda*, *à sua frente* ou *à sua direita*
- Alerta de proximidade crescente: *próximo* (>15% do frame) e *muito próximo* (>30%)
- Buffer de confirmação: objeto precisa permanecer visível por tempo mínimo antes do aviso
- Reaviso periódico para objetos que continuam no campo de visão
- Concordância de gênero gramatical nos anúncios em português brasileiro
- Síntese de voz em português brasileiro (Android TTS nativo via `flutter_tts`)
