"""
Exporta o modelo YOLOv8 para TFLite (int8 e float16) a 256x256.

Estratégia para contornar o conflito ultralytics vs tf_keras vs TF 2.21:
  1. Instala tf_keras==2.21.0 antes de qualquer import do ultralytics
  2. Aplica patch em tf.__internal__ para a função ausente no TF 2.21
  3. Bloqueia o auto-update do ultralytics para impedir o downgrade
"""
import subprocess, sys, os, shutil

# ── 1. Garante tf_keras compatível ANTES de qualquer import ultralytics ────────
subprocess.run(
    [sys.executable, '-m', 'pip', 'install', 'tf-keras==2.21.0', '-q'],
    check=False
)

# ── 2. Patch: adiciona função ausente no TF 2.21 que tf_keras 2.15 espera ─────
import tensorflow as tf
if not hasattr(tf.__internal__, 'register_load_context_function'):
    tf.__internal__.register_load_context_function = lambda fn: fn

# ── 3. Bloqueia o auto-update do ultralytics (evita downgrade do tf_keras) ────
import ultralytics.utils.checks as _uc
def _noop(*_, **_kw): pass  # pyright: ignore[reportUnusedParameter]
_uc.check_requirements = _noop

from ultralytics import YOLO

# ── Configurações ──────────────────────────────────────────────────────────────
MODELO_ORIGEM  = "runs/detect/modelos/treino_tcc_v13/weights/best.pt"
PASTA_DESTINO  = "exports"
ASSETS_ANDROID = "app_mobile/android/app/src/main/assets"
IMGSZ          = 256   # 256² vs 320² = 37% menos computação

def exportar(int8: bool):
    sufixo    = "int8" if int8 else "float16"
    nome      = f"best_{sufixo}.tflite"
    print(f"\n{'='*55}")
    print(f"Exportando: {nome}  |  imgsz={IMGSZ}  |  TF {tf.__version__}")
    print(f"{'='*55}\n")

    modelo = YOLO(MODELO_ORIGEM)
    caminho = modelo.export(
        format="tflite",
        imgsz=IMGSZ,
        half=not int8,   # float16 quando não é int8
        int8=int8,
        data="dados/brutos/data.yaml" if int8 else None,
    )

    os.makedirs(PASTA_DESTINO,  exist_ok=True)
    os.makedirs(ASSETS_ANDROID, exist_ok=True)

    destino         = os.path.join(PASTA_DESTINO,  nome)
    destino_android = os.path.join(ASSETS_ANDROID, nome)

    shutil.move(caminho, destino)
    shutil.copy2(destino, destino_android)

    mb = os.path.getsize(destino) / 1024 / 1024
    print(f"\n  exports/        → {destino}  ({mb:.1f} MB)")
    print(f"  assets Android  → {destino_android}")

if __name__ == "__main__":
    if not os.path.exists(MODELO_ORIGEM):
        print(f"ERRO: Modelo não encontrado em '{MODELO_ORIGEM}'")
        sys.exit(1)

    exportar(int8=True)
    exportar(int8=False)

    print("\n\nPróximos passos:")
    print("1. No camera_screen.dart  modelPath já está como 'best_int8'")
    print("2. Execute: JAVA_HOME=\"C:/Program Files/Android/Android Studio/jbr\" flutter build apk --release")
    print("3. Instale o APK e teste o FPS")
    print("4. Se a precisão do int8 cair, troque para 'best_float16'")
