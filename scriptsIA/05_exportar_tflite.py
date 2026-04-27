"""
Exporta o modelo YOLOv8 para TFLite (int8 e float16) a 256x256.
"""
import subprocess, sys, os, shutil, json, hashlib
from datetime import datetime

# ── 1. Garante tf_keras compatível ANTES de qualquer import ultralytics ────────
subprocess.run(
    [sys.executable, '-m', 'pip', 'install', 'tf-keras==2.21.0', '-q'],
    check=False
)

# ── 2. Patch: adiciona função ausente no TF 2.21 ──────────────────────────────
import tensorflow as tf
if not hasattr(tf.__internal__, 'register_load_context_function'):
    tf.__internal__.register_load_context_function = lambda fn: fn

# ── 3. Bloqueia o auto-update do ultralytics ──────────────────────────────────
import ultralytics.utils.checks as _uc
def _noop(*_, **_kw): pass
_uc.check_requirements = _noop

from ultralytics import YOLO

# ── Configurações ──────────────────────────────────────────────────────────────
MODELO_ORIGEM  = sys.argv[1] if len(sys.argv) > 1 else "runs/detect/modelos/treino_tcc_v20260424_1205/weights/best.pt"
PASTA_DESTINO  = "exports"
ASSETS_ANDROID = "app_mobile/android/app/src/main/assets"
IMGSZ          = 256

def hash_arquivo(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        h.update(f.read())
    return h.hexdigest()[:8]

def exportar(int8: bool):
    sufixo = "int8" if int8 else "float16"
    nome   = f"best_{sufixo}.tflite"
    print(f"\n{'='*55}")
    print(f"Exportando: {nome}  |  imgsz={IMGSZ}  |  TF {tf.__version__}")
    print(f"{'='*55}\n")

    modelo  = YOLO(MODELO_ORIGEM)
    caminho = modelo.export(
        format="tflite",
        imgsz=IMGSZ,
        half=not int8,
        int8=int8,
        data="dados/brutos/data.yaml" if int8 else None,
    )

    if not caminho or not os.path.exists(caminho):
        print(f"ERRO: Export falhou — arquivo não encontrado: {caminho}")
        return False

    os.makedirs(PASTA_DESTINO, exist_ok=True)

    destino = os.path.join(PASTA_DESTINO, nome)
    shutil.move(caminho, destino)

    mb  = os.path.getsize(destino) / 1024 / 1024
    md5 = hash_arquivo(destino)
    print(f"  exports/  → {destino}  ({mb:.1f} MB  |  MD5: {md5})")

    # ✅ Só copia para Android se a pasta existir
    if os.path.exists(ASSETS_ANDROID):
        shutil.copy2(destino, os.path.join(ASSETS_ANDROID, nome))
        print(f"  Android   → {ASSETS_ANDROID}/{nome}")
    else:
        print(f"  [AVISO] Pasta Android não encontrada, pulando: {ASSETS_ANDROID}")

    return True

if __name__ == "__main__":
    if not os.path.exists(MODELO_ORIGEM):
        print(f"ERRO: Modelo não encontrado em '{MODELO_ORIGEM}'")
        sys.exit(1)

    exportar(int8=True)
    exportar(int8=False)

    resumo = {
        "data":           datetime.now().strftime("%Y-%m-%d %H:%M"),
        "modelo_origem":  MODELO_ORIGEM,
        "imgsz":          IMGSZ,
        "tensorflow":     tf.__version__,
        "arquivos":       {}
    }
    for sufixo in ["int8", "float16"]:
        path = os.path.join(PASTA_DESTINO, f"best_{sufixo}.tflite")
        if os.path.exists(path):
            resumo["arquivos"][sufixo] = {
                "tamanho_mb": round(os.path.getsize(path) / 1024 / 1024, 2),
                "md5":        hash_arquivo(path)
            }

    with open(os.path.join(PASTA_DESTINO, "export_info.json"), "w") as f:
        json.dump(resumo, f, indent=2, ensure_ascii=False)

    print(f"\nResumo salvo em: {PASTA_DESTINO}/export_info.json")
    print("\nPróximos passos:")
    print("1. No camera_screen.dart  modelPath já está como 'best_int8'")
    print("2. Execute: flutter build apk --release")
    print("3. Instale o APK e teste o FPS")
    print("4. Se a precisão do int8 cair, troque para 'best_float16'")