from ultralytics import YOLO
import torch
import json
import os
from datetime import datetime

def treinar_modelo():
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Dispositivo detectado: {device.upper()}")

    versao = datetime.now().strftime("v%Y%m%d_%H%M")
    name = f"treino_tcc_{versao}"
    print(f"Nome do treino: {name}")

    print("Carregando o cérebro base (YOLOv8 Nano)...")
    modelo = YOLO("yolov8n.pt")

    print("Iniciando o treinamento... Isso pode demorar!")
    resultados = modelo.train(
        data="dados/brutos/data.yaml",
        epochs=100,
        imgsz=640,
        batch=8,
        device=device,
        patience=20,
        workers=0,
        project="modelos",
        name=name,
        exist_ok=True,
    )

    metricas = {
        "mAP50":     resultados.results_dict.get("metrics/mAP50(B)", 0),
        "mAP50-95":  resultados.results_dict.get("metrics/mAP50-95(B)", 0),
        "precision": resultados.results_dict.get("metrics/precision(B)", 0),
        "recall":    resultados.results_dict.get("metrics/recall(B)", 0),
    }

    with open(f"runs/detect/modelos/{name}/metricas.json", "w") as f:
        json.dump(metricas, f, indent=2)

    print(f"\nTreinamento finalizado!")
    print(f"mAP50:     {metricas['mAP50']:.4f}")
    print(f"mAP50-95:  {metricas['mAP50-95']:.4f}")
    print(f"Precision: {metricas['precision']:.4f}")
    print(f"Recall:    {metricas['recall']:.4f}")
    print(f"Modelo salvo em: modelos/{name}/weights/best.pt")

    print(f"\nPróximo passo: exportar para TFLite com o script 05_exportar_tflite.py")
    print(f"  python scriptsIA/05_exportar_tflite.py runs/detect/modelos/{name}/weights/best.pt")

if __name__ == "__main__":
    treinar_modelo()