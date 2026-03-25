from ultralytics import YOLO

def treinar_modelo():
    print("Carregando o cérebro base (YOLOv8 Small)...")
    # Carregamos o modelo base que já sabe identificar formas e bordas genéricas
    modelo = YOLO("yolov8s.pt")

    print("Iniciando o treinamento (Fine-Tuning)... Isso pode demorar!")
    # O comando .train() é onde a mágica acontece
    resultados = modelo.train(
        data="dados/brutos/data.yaml", # O caminho para o nosso 'cardápio' de imagens
        epochs=25,                     # Quantas vezes a IA vai analisar o dataset completo
        imgsz=640,                     # Resolução das imagens que a IA vai processar
        batch=8,                       # Quantas imagens a IA lê por vez (8 evita travar a memória)
        project="modelos",             # Pasta onde ele vai salvar o resultado final
        name="treino_tcc_v1"           # Nome da subpasta desse teste específico
    )
    
    print("Treinamento finalizado com sucesso!")

if __name__ == "__main__":
    treinar_modelo()