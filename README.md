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
| Detecção de objetos | YOLOv8n (Ultralytics) |
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
| `Chair` | Cadeira | Média |
| `table` | Mesa | Média |
| `elevator` | Elevador | Média |
| `elevator sign` | Placa de elevador | Média |
| `stair sign` | Placa de escada | Média |
| `exit sign` | Sinalização de saída | Média |
| `fire extinguisher` | Extintor de incêndio | Média |
| `acessibility` | Acessibilidade | Média |
| `trash can` | Lixeira | Média |
| `water dispenser` | Bebedouro | Média |
| `fire alarm` | Alarme de incêndio | Baixa |
| `handle` | Maçaneta | Baixa |
| `push handle` | Maçaneta de empurrar | Baixa |
| `men washroom` | Banheiro masculino | Baixa |
| `women washrooom` | Banheiro feminino | Baixa |

---

## Datasets Utilizados no Treinamento

O dataset final utilizado nos treinamentos é uma junção dos quatro datasets públicos abaixo + as imagens próprias coletadas no campus da UNIT e em outros lugares com os objetos presentes nas universidades:

| Split | Imagens |
|---|---|
| Treino | 11.847 |
| Validação | 1.883 |
| Teste | 1.008 |
| **Total** | **14.738** |

- **Dataset final (treinamento atual)** — [deteccao-de-objetos-faculdade](https://universe.roboflow.com/breno-s-workspace/deteccao-de-objetos-faculdade)

Datasets de origem:

- [indoor-navigation (akhash)](https://universe.roboflow.com/akhash/indoor-navigation-xs4of)
- [person-detection (titulacin)](https://universe.roboflow.com/titulacin/person-detection-9a6mk)
- [indoor-navigation-v8ctg (final-project-4152)](https://universe.roboflow.com/final-project-4152/indoor-navigation-v8ctg)
- [door-detection (cody-pwtvk)](https://universe.roboflow.com/cody-pwtvk/door-detection-j97hy)

---

## Estrutura do Projeto

```
TCC_VisaoComputacional/
│
├── scriptsIA/
│   ├── 01_testeCamera.py          # Diagnóstico da câmera
│   ├── 02_reconhecimentoYolo.py   # Visualização das detecções com FPS
│   ├── 03_treinamento_yolo.py     # Fine-tuning do YOLOv8
│   ├── 03_teste_voz_pyttsx3.py    # Teste de síntese de voz com pyttsx3
│   ├── 04_assistente_completo.py  # Assistente de voz com reconhecimento em tempo real
│   └── 05_exportar_tflite.py      # Exportação int8 e float16 para Android (640×640)
│
├── dados/
│   ├── brutos/                    # Imagens coletadas na UNIT (ignoradas pelo .gitignore)
│   └── anotados/                  # Dataset rotulado para treino (ignorado pelo .gitignore)
│
├── runs/                          # Resultados dos treinamentos (pesos, métricas, gráficos)
│   └── detect/modelos/
│       └── treino_tcc_v20260615_1028/  # Melhor modelo treinado (mAP50: 76.2%, 17 classes)
│
├── exports/                       # Modelos exportados (ignorados pelo .gitignore)
│   ├── best_int8.tflite           # Quantizado int8, 640×640 (~3 MB) — uso no app
│   └── best_float16.tflite        # Float16, 640×640 (~6 MB) — fallback de precisão
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

O modelo atual (`treino_tcc_v20260615_1028`) foi treinado com fine-tuning sobre o YOLOv8n com as seguintes métricas:

| Métrica | Valor |
|---|---|
| mAP50 | 76.2% |
| mAP50-95 | 56.8% |
| Precisão | 78.3% |
| Recall | 71.0% |
| Épocas | 50 |

### Métricas por classe

Métricas avaliadas no split de teste (1.008 imagens, 2.858 instâncias):

| Classe | Precisão | Recall | mAP50 | mAP50-95 |
|---|---|---|---|---|
| `Chair` | 71.3% | 55.3% | 64.0% | 40.7% |
| `acessibility` | 72.0% | 79.4% | 77.8% | 58.4% |
| `door` | 76.9% | 77.1% | 82.6% | 62.2% |
| `elevator` | 74.1% | 60.0% | 70.2% | 52.4% |
| `elevator sign` | 69.4% | 61.6% | 67.8% | 47.2% |
| `exit sign` | 73.1% | 78.7% | 78.4% | 58.8% |
| `fire alarm` | 87.0% | 81.5% | 86.7% | 69.0% |
| `fire extinguisher` | 90.8% | 74.3% | 83.2% | 54.2% |
| `handle` | 65.7% | 58.3% | 60.0% | 40.5% |
| `men washroom` | 81.6% | 77.8% | 84.0% | 55.0% |
| `person` | 84.0% | 78.5% | 85.0% | 55.6% |
| `push handle` | 60.1% | 59.2% | 62.3% | 46.3% |
| `stair sign` | 76.8% | 72.7% | 80.4% | 63.2% |
| `table` | 76.9% | 33.7% | 44.1% | 31.5% |
| `trash can` | 88.1% | 87.1% | 90.7% | 69.9% |
| `water dispenser` | 96.6% | 92.3% | 97.9% | 93.0% |
| `women washrooom` | 85.8% | 78.9% | 81.0% | 68.1% |

> As métricas acima foram medidas na resolução de treinamento (640×640). As métricas na resolução de inferência do app variam conforme a resolução de exportação — ver tabela abaixo.

> A classe `table` (mAP50: 44,1%) possui desempenho abaixo do ideal por limitação de imagens de treinamento (157 instâncias) e é candidata a melhoria com coleta adicional de dados.

### Comparativo de resoluções de exportação

Validações realizadas com o mesmo modelo (`treino_tcc_v20260615_1028`) em diferentes resoluções de inferência:

| Resolução | mAP50 | mAP50-95 | Precisão | Recall | FPS estimado (Redmi Note 10 e Redmi Note 13) |
|---|---|---|---|---|---|
| 256×256 | 54.2% | 36.0% | 68.5% | 49.7% | 7–15 FPS |
| 320×320 | 61.2% | 43.5% | 74.5% | 55.0% | 4–9 FPS |
| 416×416 | 68.9% | 50.2% | 72.6% | 65.0% | 2–4 FPS |
| **640×640** | **76.2%** | **56.8%** | **78.3%** | **71.0%** | **~2 FPS** |

> A resolução atual de exportação é **640×640** — mesma do treinamento, máxima qualidade de detecção.

### Formatos exportados

| Arquivo | Formato | Tamanho | Resolução | Uso |
|---|---|---|---|---|
| `best_int8.tflite` | Int8 quantizado | ~3 MB | 640×640 | App (padrão) |
| `best_float16.tflite` | Float16 | ~6 MB | 640×640 | Fallback de precisão |
| `best_float32.tflite` | Float32 | ~12 MB | 640×640 | Precisão máxima |

Os arquivos `.tflite` e o `.pt` não estão versionados no repositório. Há duas formas de obtê-los:

**Opção 1 — Baixar do GitHub Release (recomendado):**

```bash
python setup_modelos.py
```

O script baixa automaticamente `best_int8.tflite`, `best_float16.tflite` e `best.pt` da release mais recente e os coloca nas pastas corretas (`exports/` e `app_mobile/android/app/src/main/assets/`).

**Opção 2 — Gerar a partir do modelo treinado:**

```bash
python scriptsIA/05_exportar_tflite.py runs/detect/modelos/treino_tcc_v20260615_1028/weights/best.pt
```

Requer o arquivo `best.pt` disponível localmente em `runs/detect/modelos/treino_tcc_v20260615_1028/weights/`.

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

---

## Histórico de Releases

| Release | Resolução | Descrição |
|---|---|---|
| [v1.0-modelos](https://github.com/breeramon/TCC_VisaoComputacional/releases/tag/v1.0-modelos) | 256×256 | Primeira exportação — calibração int8 com dataset externo (coco8) |
| [v2.0-modelos](https://github.com/breeramon/TCC_VisaoComputacional/releases/tag/v2.0-modelos) | 256×256 | Calibração int8 corrigida com 826 imagens reais do dataset próprio |
| [v3.0-modelos](https://github.com/breeramon/TCC_VisaoComputacional/releases/tag/v3.0-modelos) | 640×640 | Resolução de exportação elevada para 640×640 (mesma do treinamento) |
| [v4.0-modelos](https://github.com/breeramon/TCC_VisaoComputacional/releases/tag/v4.0-modelos) | 640×640 | Novo treinamento com 17 classes (adicionadas Chair e table) + APKs do app |

---

## Limitações e Trabalhos Futuros

### Limitações atuais

- O modelo detecta **que existe** um objeto de uma classe, mas não lê conteúdo textual dentro dele. Placas de sala, por exemplo, são identificadas como presença de placa, sem distinção do número.
- O desempenho de inferência é limitado pelo hardware do dispositivo. Celulares com GPU fraca (ex: Snapdragon 685) operam entre 2–5 FPS — ~2 FPS na resolução máxima (640×640) e até 15 FPS na resolução reduzida (256×256).
- A classe `table` (mAP50: 44,1%) ainda possui desempenho abaixo do ideal por limitação de imagens de treinamento (157 instâncias).
- O estudo de caso é restrito ao campus Farolândia da UNIT — o modelo pode ter desempenho reduzido em outros ambientes internos com características visuais distintas.

### Possibilidades de expansão

- **Leitura de números de sala via OCR:** Integrar o [ML Kit Text Recognition](https://developers.google.com/ml-kit/vision/text-recognition/v2) do Google (gratuito, roda offline no Android) para, após detectar uma placa de sala, extrair e anunciar o número por voz — permitindo ao usuário saber exatamente em qual sala está.
- **Novas classes:** Adição de `stairs` (escadas), `bench` (banco/assento) e `drinking fountain` para ampliar a cobertura de obstáculos comuns em ambientes universitários.
- **Suporte a outros campi:** Coleta de imagens em outros ambientes da UNIT ou outras instituições para aumentar a generalização do modelo.
- **Modo de baixo consumo:** Redução dinâmica de `inferenceFrequency` quando a bateria estiver abaixo de um limiar, preservando a autonomia do dispositivo.
- **Feedback tátil:** Combinação de vibração com os avisos de voz para usuários com deficiência auditiva concomitante.
