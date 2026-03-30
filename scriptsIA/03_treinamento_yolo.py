from ultralytics import YOLO
import torch

def treinar_modelo():
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Dispositivo detectado: {device.upper()}")

    print("Carregando o cérebro base (YOLOv8 Small)...")
    modelo = YOLO("yolov8s.pt")

    print("Iniciando o treinamento (Fine-Tuning)... Isso pode demorar!")
    resultados = modelo.train(
        data="dados/brutos/data.yaml",
        epochs=50,          # Mais épocas, compensado pelo early stopping
        imgsz=640,
        batch=8,
        device=device,      # Força GPU se disponível
        patience=10,        # Para se não melhorar por 10 épocas (early stopping)
        workers=0,          # Necessário no Windows para evitar erro de multiprocessing
        project="modelos",
        name="treino_tcc_v1",
        exist_ok=True,      # Evita erro se a pasta já existir ao re-treinar
    )

    print(f"\nTreinamento finalizado com sucesso!")
    print(f"mAP50:    {resultados.results_dict.get('metrics/mAP50(B)', 'N/A'):.4f}")
    print(f"mAP50-95: {resultados.results_dict.get('metrics/mAP50-95(B)', 'N/A'):.4f}")
    print(f"Modelo salvo em: modelos/treino_tcc_v1/weights/best.pt")

if __name__ == "__main__":
    treinar_modelo()
