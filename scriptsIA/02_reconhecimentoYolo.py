import cv2
import time
import sys
from ultralytics import YOLO

CONFIANCA = 0.6
MODELO_PATH = sys.argv[1] if len(sys.argv) > 1 else "runs/detect/modelos/treino_tcc_v20260429_0902/weights/best.pt"

def reconhecer_objetos():
    print(f"Carregando modelo: {MODELO_PATH}")
    modelo = YOLO(MODELO_PATH)

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Erro: Não foi possível acessar a câmera.")
        return

    print("IA iniciada! Pressione 'q' para sair.")
    tempo_anterior = time.time()

    while True:
        sucesso, frame = cap.read()
        if not sucesso:
            print("Falha ao capturar o frame.")
            break

        frame_anotado = frame
        resultados_lista = list(modelo(frame, conf=CONFIANCA, stream=True))

        for resultado in resultados_lista:
            frame_anotado = resultado.plot()

        tempo_atual = time.time()
        delta = tempo_atual - tempo_anterior
        fps = 1.0 / delta if delta > 0 else 0.0
        tempo_anterior = tempo_atual

        total_objetos = sum(len(r.boxes) for r in resultados_lista)

        cv2.imshow("YOLOv8 TCC Breno", frame_anotado)
        cv2.setWindowTitle("YOLOv8 TCC Breno",
            f"YOLOv8 TCC Breno | FPS: {fps:.1f} | Objetos: {total_objetos}")

        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("Encerrando...")
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    reconhecer_objetos()