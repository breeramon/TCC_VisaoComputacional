"""
Baixa os modelos TFLite da GitHub Release e os coloca nas pastas corretas.

Uso:
    python setup_modelos.py              # baixa a release mais recente
    python setup_modelos.py v1.0-modelos # baixa uma release específica
"""

import sys
import os
import urllib.request
import json
import shutil

REPO = "breeramon/TCC_VisaoComputacional"

DESTINOS = {
    "best_int8.tflite": [
        "exports/best_int8.tflite",
        "app_mobile/android/app/src/main/assets/best_int8.tflite",
    ],
    "best_float16.tflite": [
        "exports/best_float16.tflite",
        "app_mobile/android/app/src/main/assets/best_float16.tflite",
    ],
    "best.pt": [
        "exports/best.pt",
    ],
}


def buscar_release(tag=None):
    if tag:
        url = f"https://api.github.com/repos/{REPO}/releases/tags/{tag}"
    else:
        url = f"https://api.github.com/repos/{REPO}/releases/latest"

    req = urllib.request.Request(url, headers={"User-Agent": "setup_modelos"})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def baixar_arquivo(url, destino):
    os.makedirs(os.path.dirname(destino) or ".", exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "setup_modelos"})

    with urllib.request.urlopen(req) as r:
        total = int(r.headers.get("Content-Length", 0))
        baixado = 0
        with open(destino, "wb") as f:
            while chunk := r.read(8192):
                f.write(chunk)
                baixado += len(chunk)
                if total:
                    pct = baixado * 100 // total
                    print(f"\r  Baixando {os.path.basename(destino)}... {pct}%", end="", flush=True)
    print()

    if total and os.path.getsize(destino) != total:
        raise RuntimeError(f"Arquivo corrompido: esperado {total} bytes, recebido {os.path.getsize(destino)}")


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else None

    print(f"Buscando release {'mais recente' if not tag else tag} em {REPO}...")
    try:
        release = buscar_release(tag)
    except Exception as e:
        print(f"ERRO: Não foi possível acessar a release — {e}")
        print("Verifique se já existe uma Release criada no GitHub com os modelos anexados.")
        sys.exit(1)

    print(f"Release encontrada: {release['tag_name']} — {release['name']}\n")

    assets = {a["name"]: a["browser_download_url"] for a in release["assets"]}

    if not assets:
        print("ERRO: A release não possui arquivos anexados.")
        print(f"Acesse github.com/{REPO}/releases e anexe os .tflite.")
        sys.exit(1)

    for nome_arquivo, destinos in DESTINOS.items():
        if nome_arquivo not in assets:
            print(f"[AVISO] {nome_arquivo} não encontrado na release, pulando.\n")
            continue

        tmp = f"_tmp_{nome_arquivo}"
        try:
            baixar_arquivo(assets[nome_arquivo], tmp)
            for destino in destinos:
                os.makedirs(os.path.dirname(destino) or ".", exist_ok=True)
                shutil.copy2(tmp, destino)
                print(f"  Copiado → {destino}")
            print()
        except Exception as e:
            print(f"  ERRO ao baixar {nome_arquivo}: {e}\n")
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)

    print("Modelos prontos. Você já pode rodar o app Flutter.")


if __name__ == "__main__":
    main()
