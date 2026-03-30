from ultralytics import YOLO
import os

MODELO_ORIGEM = "runs/detect/modelos/treino_tcc_v13/weights/best.pt"
PASTA_DESTINO = "exports"

def exportar_tflite():
    if not os.path.exists(MODELO_ORIGEM):
        print(f"ERRO: Modelo não encontrado em '{MODELO_ORIGEM}'")
        return

    os.makedirs(PASTA_DESTINO, exist_ok=True)

    print(f"Carregando modelo: {MODELO_ORIGEM}")
    modelo = YOLO(MODELO_ORIGEM)

    print("\nExportando para TFLite (float32)...")
    print("Isso pode levar alguns minutos na primeira vez.\n")

    caminho_exportado = modelo.export(
        format="tflite",
        imgsz=640,      # Deve ser igual ao tamanho usado no treinamento
        int8=False,     # False = float32 (mais preciso, arquivo maior ~12MB)
                        # True  = int8 quantizado (mais leve ~3MB, exige calibração)
    )

    # Move o arquivo gerado para a pasta exports/
    nome_arquivo = os.path.basename(caminho_exportado)
    destino_final = os.path.join(PASTA_DESTINO, nome_arquivo)
    os.replace(caminho_exportado, destino_final)

    print(f"\nExportação concluída!")
    print(f"Arquivo salvo em: {destino_final}")
    print(f"Tamanho: {os.path.getsize(destino_final) / 1024 / 1024:.1f} MB")
    print("\nPróximo passo: copiar este arquivo para assets/ do app Flutter.")

if __name__ == "__main__":
    exportar_tflite()
