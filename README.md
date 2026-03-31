# Sistema de Navegação Indoor por Voz para Pessoas com Deficiência Visual

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
| Linguagem | Python 3.x |
| Detecção de objetos | YOLOv8 (Ultralytics) |
| Inferência no Android | TensorFlow Lite |
| Processamento de frames | OpenCV |
| Síntese de voz (protótipo PC) | Windows TTS via subprocess |
| App mobile | Flutter |

---

## Classes de Objetos Detectados

- Porta
- Elevador
- Extintor de incêndio
- Lixeira
- Bebedouro
- Pessoa
- Placa de escada
- Sinalização de saída
- mais objetos serão adicionados...

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
│   └── 05_exportar_tflite.py      # Exportação do modelo para Android (.tflite)
│
├── dados/
│   ├── brutos/                    # Imagens coletadas na UNIT (ignoradas pelo .gitignore)
│   └── anotados/                  # Dataset rotulado para treino (ignorado pelo .gitignore)
│
├── runs/                          # Resultados dos treinamentos (pesos, métricas, gráficos)
│   └── detect/modelos/
│       └── treino_tcc_v13/        # Melhor modelo treinado (mAP50: 82.3%)
│
├── exports/                       # Modelos exportados para uso no Flutter
│   └── best_float32.tflite        # Modelo TFLite gerado (42.7 MB) — ignorado pelo .gitignore
│
├── requirements.txt               # Dependências Python
└── .gitignore
```

---

## Como Executar o Protótipo (PC)

### 1. Instalar dependências
```bash
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

> **Nota:** Os scripts de PC utilizam o [Iriun Webcam](https://iriun.com/) para espelhar a câmera do celular Android no computador durante o desenvolvimento, visto que alguns PC não possuem câmera ou webcam.

---

## Modelo Treinado

O modelo atual (`treino_tcc_v13`) foi treinado com fine-tuning sobre o YOLOv8s com as seguintes métricas:

| Métrica | Valor |
|---|---|
| mAP50 | 82.3% |
| mAP50-95 | 57.7% |
| Precisão | 82.2% |
| Recall | 77.5% |
| Épocas | 25 (early stopping) |

O arquivo `.tflite` gerado não está versionado no repositório devido ao tamanho (42.7 MB). Para obtê-lo, execute o script `05_exportar_tflite.py` com o modelo `.pt` disponível em `runs/detect/modelos/treino_tcc_v13/weights/best.pt`.

---

## App Android (Flutter)

O aplicativo mobile foi desenvolvido em Flutter para Android, integrando inferência TFLite em tempo real com síntese de voz nativa (Android TTS) em português brasileiro.

### Estrutura do App

```
app_mobile/
├── lib/
│   ├── main.dart                      # Ponto de entrada — gerencia permissão de câmera
│   ├── detector/
│   │   └── object_detector.dart       # Pipeline TFLite: captura → inferência → NMS
│   ├── tts/
│   │   └── tts_service.dart           # Lógica de avisos de voz com prioridade e buffer
│   └── screens/
│       └── camera_screen.dart         # UI: preview da câmera + overlay das detecções
│
├── assets/
│   ├── labels.txt                     # 17 classes em português (ordem do modelo)
│   └── model/
│       └── best_float32.tflite        # Modelo exportado (copiar de exports/)
│
└── android/
    └── app/
        ├── build.gradle.kts           # Configurações de compilação Android
        └── src/main/AndroidManifest.xml
```

### Pré-requisitos

- [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado e no PATH
- Android SDK com API 31 ou superior
- Celular Android com **Depuração USB** ativada (Opções do desenvolvedor)
- Modelo exportado: executar `05_exportar_tflite.py` e copiar o `.tflite` para `app_mobile/assets/model/`

### Como Compilar e Instalar

```bash
# 1. Copiar o modelo exportado para os assets
cp exports/best_float32.tflite app_mobile/assets/model/best_float32.tflite

# 2. Instalar dependências Flutter
cd app_mobile
flutter pub get

# 3. Compilar e instalar no celular conectado via USB
flutter run
```

### Funcionalidades do App

- Detecção de objetos em tempo real via câmera traseira
- Sistema de prioridade: Pessoa (alta) → pontos de navegação (média) → referências (baixa)
- Posição espacial do objeto: esquerda, frente ou direita
- Alerta de proximidade: aviso adicional quando objeto ocupa >15% do frame
- Buffer de confirmação: objeto precisa ser detectado por tempo mínimo antes do aviso
- Síntese de voz em português brasileiro (Android TTS nativo)
