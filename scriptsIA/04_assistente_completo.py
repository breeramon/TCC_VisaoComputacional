import cv2
from ultralytics import YOLO
import subprocess
import threading
import time
import queue

# 1. Dicionário de tradução
traducao_classes = {
    'door': 'Porta',
    'elevator': 'Elevador',
    'fire extinguisher': 'Extintor de incêndio',
    'trash can': 'Lixeira',
    'water dispenser': 'Bebedouro',
    'person': 'Pessoa',
    'stair sign': 'Placa de escada',
    'exit sign': 'Sinalização de saída'
}

# 2. Criando a Fila de comunicação
fila_fala = queue.Queue()

def trabalhador_voz():
    """Thread dedicada à fala usando PowerShell + System.Speech (evita conflito com OpenCV no Windows)."""
    while True:
        texto = fila_fala.get()
        if texto is None:
            break

        print(f"Assistente diz: {texto}")
        try:
            texto_escapado = texto.replace("'", "''")
            script = (
                "Add-Type -AssemblyName System.Speech; "
                "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
                "$s.Rate = 2; "
                "try { $s.SelectVoiceByHints("
                    "[System.Speech.Synthesis.VoiceGender]::NotSet, "
                    "[System.Speech.Synthesis.VoiceAge]::NotSet, 0, "
                    "[System.Globalization.CultureInfo]::GetCultureInfo('pt-BR')) } catch {}; "
                f"$s.Speak('{texto_escapado}')"
            )
            subprocess.run(
                ["powershell", "-Command", script],
                capture_output=True,
                timeout=15
            )
        except Exception as e:
            print(f"[VOZ] Erro: {e}")

        fila_fala.task_done()

def iniciar_assistente():
    # 3. Ligamos o nosso "funcionário da voz" uma única vez no início
    thread_voz = threading.Thread(target=trabalhador_voz, daemon=True)
    thread_voz.start()

    print("Carregando o cérebro da IA (Modelo Customizado)...")
    modelo = YOLO("runs/detect/modelos/treino_tcc_v13/weights/best.pt")
    
    print("Ligando a câmera no canal 0...")
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("ERRO FATAL: O Python não encontrou nenhuma câmera no canal 0.")
        return

    TEMPO_CONFIRMACAO = 0.8  # segundos que o objeto precisa estar visível antes de ser anunciado
    TEMPO_REAVISO    = 5.0  # segundos mínimos entre repetições do mesmo objeto

    em_confirmacao = {}  # obj -> timestamp da primeira detecção contínua
    ultimo_aviso   = {}  # obj -> timestamp do último anúncio

    while True:
        ret, frame = cap.read()
        if not ret:
            print("ERRO: O Iriun está conectado, mas a imagem do celular falhou.")
            break

        resultados = modelo(frame, conf=0.6, stream=True)
        objetos_detectados = set()

        for r in resultados:
            boxes = r.boxes
            for box in boxes:
                classe_id = int(box.cls[0])
                nome_original = modelo.names[classe_id]
                nome_traduzido = traducao_classes.get(nome_original, nome_original)

                objetos_detectados.add(nome_traduzido)

                x1, y1, x2, y2 = map(int, box.xyxy[0])
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                cv2.putText(frame, nome_traduzido, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

        tempo_atual = time.time()

        # Remove da confirmação objetos que saíram do frame (reset do timer)
        for obj in list(em_confirmacao.keys()):
            if obj not in objetos_detectados:
                del em_confirmacao[obj]

        # Registra o momento em que cada objeto apareceu pela primeira vez nesta janela
        for obj in objetos_detectados:
            if obj not in em_confirmacao:
                em_confirmacao[obj] = tempo_atual

        # Anuncia somente objetos estáveis há >= TEMPO_CONFIRMACAO e não anunciados recentemente
        novos_objetos = []
        for obj, primeiro_visto in em_confirmacao.items():
            estavel = (tempo_atual - primeiro_visto) >= TEMPO_CONFIRMACAO
            nao_recente = obj not in ultimo_aviso or (tempo_atual - ultimo_aviso[obj]) > TEMPO_REAVISO
            if estavel and nao_recente:
                novos_objetos.append(obj)
                ultimo_aviso[obj] = tempo_atual

        if novos_objetos:
            if len(novos_objetos) == 1:
                texto_aviso = f"{novos_objetos[0]} detectado."
            else:
                texto_aviso = f"{', '.join(novos_objetos[:-1])} e {novos_objetos[-1]} detectados."
            fila_fala.put(texto_aviso)

        cv2.imshow("Assistente de Navegacao TCC", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    iniciar_assistente()