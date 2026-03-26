import cv2
import time
from ultralytics import YOLO

def reconhecer_objetos():
    print("Carregando o modelo YOLOv8 personalizado...")
    modelo = YOLO("runs/detect/modelos/treino_tcc_v13/weights/best.pt")

    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("Erro: Não foi possível acessar a câmera do Iriun.")
        return

    print("IA iniciada! Pressione 'q' para sair.")

    tempo_anterior = time.time()

    while True:
        sucesso, frame = cap.read()

        if not sucesso:
            print("Falha ao capturar o frame.")
            break

        # Valor padrão para frames sem nenhuma detecção (evita NameError)
        frame_anotado = frame

        resultados = modelo(frame, conf=0.6, stream=True)

        for resultado in resultados:
            frame_anotado = resultado.plot()

        # Calcula e exibe o FPS no título da janela
        tempo_atual = time.time()
        fps = 1.0 / (tempo_atual - tempo_anterior)
        tempo_anterior = tempo_atual

        cv2.imshow("YOLOv8 TCC Breno", frame_anotado)
        cv2.setWindowTitle("YOLOv8 TCC Breno", f"YOLOv8 TCC Breno | FPS: {fps:.1f}")

        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("Encerrando a Inteligência Artificial...")
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    reconhecer_objetos()