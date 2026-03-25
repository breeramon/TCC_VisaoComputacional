import cv2
from ultralytics import YOLO

def reconhecer_objetos():
    # Carrega o modelo 'small' (yolov8s.pt), que é o mais leve e rápido.
    # Na primeira vez que você rodar, ele vai baixar esse arquivo automaticamente (cerca de 6MB).
    print("Carregando o modelo YOLOv8 personalizado...")
    # Caminho atualizado para o seu modelo treinado (v13)
    modelo = YOLO("runs/detect/modelos/treino_tcc_v13/weights/best.pt")

    # Inicia a captura de vídeo. 
    # Mude para 1 ou 2 caso o Iriun Webcam não seja reconhecido no índice 0.
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("Erro: Não foi possível acessar a câmera do Iriun.")
        return

    print("IA iniciada! Aponte a câmera para objetos (pessoas, cadeiras, celulares, etc).")
    print("Pressione a tecla 'q' para sair.")

    while True:
        sucesso, frame = cap.read()
        
        if not sucesso:
            print("Falha ao capturar o frame.")
            break

        # Passa o frame pelo modelo YOLOv8
        # stream=True otimiza o processamento contínuo de vídeo
        resultados = modelo(frame, stream=True)

        # Para cada detecção feita no frame atual
        for resultado in resultados:
            # A função plot() automaticamente desenha as caixas e os nomes dos objetos
            frame_anotado = resultado.plot()

        # Mostra o resultado na tela
        cv2.imshow("Visão Computacional - YOLOv8 (TCC Breno)", frame_anotado)

        # Aguarda a tecla 'q' para encerrar
        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("Encerrando a Inteligência Artificial...")
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    reconhecer_objetos()