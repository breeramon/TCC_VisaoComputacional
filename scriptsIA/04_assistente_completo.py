import cv2
from ultralytics import YOLO
import subprocess
import threading
import time
import queue

# ── Configurações ────────────────────────────────────────────────────────────
MODELO_PATH  = "runs/detect/modelos/treino_tcc_v20260429_0902/weights/best.pt"
CONFIANCA    = 0.6
LIMIAR_PROXIMO       = 0.15
LIMIAR_MUITO_PROXIMO = 0.30

# ── Tradução de classes ───────────────────────────────────────────────────────
traducao_classes = {
    'door':              'Porta',
    'elevator':          'Elevador',
    'fire extinguisher': 'Extintor de incêndio',
    'trash can':         'Lixeira',
    'water dispenser':   'Bebedouro',
    'person':            'Pessoa',
    'stair sign':        'Placa de escada',
    'exit sign':         'Sinalização de saída',
    'handle':            'Maçaneta',
    'push handle':       'Maçaneta de empurrar',
    'acessibility':      'Símbolo de acessibilidade',
    'elevator sign':     'Placa de elevador',
    'fire alarm':        'Alarme de incêndio',
    'men washroom':      'Banheiro masculino',
    'women washroom':    'Banheiro feminino',
}

GENERO = {
    'Porta':                      'f',
    'Elevador':                   'm',
    'Extintor de incêndio':       'm',
    'Lixeira':                    'f',
    'Bebedouro':                  'm',
    'Pessoa':                     'f',
    'Placa de escada':            'f',
    'Sinalização de saída':       'f',
    'Maçaneta':                   'f',
    'Maçaneta de empurrar':       'f',
    'Símbolo de acessibilidade':  'm',
    'Placa de elevador':          'f',
    'Alarme de incêndio':         'm',
    'Banheiro masculino':         'm',
    'Banheiro feminino':          'm',
}

PRIORIDADES = {
    'Pessoa':                    (1, 0.4, 3.0, (0, 0, 255)),
    'Porta':                     (2, 0.8, 5.0, (0, 165, 255)),
    'Elevador':                  (2, 0.8, 5.0, (0, 165, 255)),
    'Placa de escada':           (2, 0.8, 5.0, (0, 165, 255)),
    'Sinalização de saída':      (2, 0.8, 5.0, (0, 165, 255)),
    'Maçaneta':                  (2, 0.8, 5.0, (0, 165, 255)),
    'Maçaneta de empurrar':      (2, 0.8, 5.0, (0, 165, 255)),
    'Placa de elevador':         (2, 0.8, 5.0, (0, 165, 255)),
    'Alarme de incêndio':        (2, 0.8, 5.0, (0, 165, 255)),
    'Extintor de incêndio':      (3, 1.0, 8.0, (0, 255, 0)),
    'Lixeira':                   (3, 1.0, 8.0, (0, 255, 0)),
    'Bebedouro':                 (3, 1.0, 8.0, (0, 255, 0)),
    'Símbolo de acessibilidade': (3, 1.0, 8.0, (0, 255, 0)),
    'Banheiro masculino':        (3, 1.0, 8.0, (0, 255, 0)),
    'Banheiro feminino':         (3, 1.0, 8.0, (0, 255, 0)),
}
PRIORIDADE_PADRAO = (3, 1.0, 8.0, (0, 255, 0))

# ── Helpers ───────────────────────────────────────────────────────────────────
def calcular_posicao(x1, x2, largura_frame):
    centro_obj = (x1 + x2) / 2
    terco = largura_frame / 3
    if centro_obj < terco:
        return 'à sua esquerda'
    elif centro_obj < 2 * terco:
        return 'à sua frente'
    return 'à sua direita'

def calcular_proximidade(area_box, area_frame):
    ratio = area_box / area_frame
    if ratio >= LIMIAR_MUITO_PROXIMO:
        return 2
    elif ratio >= LIMIAR_PROXIMO:
        return 1
    return 0

def sufixo_proximidade(nivel_prox, obj):
    genero = GENERO.get(obj, 'm')
    if nivel_prox == 2:
        return ' muito próxima' if genero == 'f' else ' muito próximo'
    elif nivel_prox == 1:
        return ' próxima' if genero == 'f' else ' próximo'
    return ''

# ── Thread de voz ─────────────────────────────────────────────────────────────
fila_fala = queue.Queue()

def trabalhador_voz():
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
            subprocess.run(["powershell", "-Command", script],
                           capture_output=True, timeout=15)
        except Exception as e:
            print(f"[VOZ] Erro: {e}")
        fila_fala.task_done()

# ── Principal ─────────────────────────────────────────────────────────────────
def iniciar_assistente():
    thread_voz = threading.Thread(target=trabalhador_voz, daemon=True)
    thread_voz.start()

    print(f"Carregando modelo: {MODELO_PATH}")
    modelo = YOLO(MODELO_PATH)

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("ERRO FATAL: Nenhuma câmera encontrada no canal 0.")
        return

    em_confirmacao       = {}
    ultimo_aviso         = {}
    ultimo_nivel_proximo = {}
    tempo_anterior       = time.time()

    while True:
        ret, frame = cap.read()
        if not ret:
            print("ERRO: Falha ao capturar frame.")
            break

        largura_frame = frame.shape[1]
        area_frame    = frame.shape[0] * frame.shape[1]
        resultados    = modelo(frame, conf=CONFIANCA, stream=True)
        objetos_detectados = {}

        for r in resultados:
            for box in r.boxes:
                classe_id      = int(box.cls[0])
                nome_original  = modelo.names[classe_id]
                nome_traduzido = traducao_classes.get(nome_original, nome_original)

                x1, y1, x2, y2 = map(int, box.xyxy[0])
                posicao    = calcular_posicao(x1, x2, largura_frame)
                area       = (x2 - x1) * (y2 - y1)
                nivel_prox = calcular_proximidade(area, area_frame)

                if nome_traduzido not in objetos_detectados or area > objetos_detectados[nome_traduzido][1]:
                    objetos_detectados[nome_traduzido] = (posicao, area, nivel_prox)

                espessura = 2 + nivel_prox * 2
                _, _, _, cor = PRIORIDADES.get(nome_traduzido, PRIORIDADE_PADRAO)
                cv2.rectangle(frame, (x1, y1), (x2, y2), cor, espessura)
                cv2.putText(frame, f"{nome_traduzido} ({posicao})",
                            (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, cor, 2)

        tempo_atual = time.time()
        delta = tempo_atual - tempo_anterior
        fps = 1.0 / delta if delta > 0 else 0.0
        tempo_anterior = tempo_atual

        # Reset de objetos que saíram do frame
        for obj in list(em_confirmacao.keys()):
            if obj not in objetos_detectados:
                del em_confirmacao[obj]
                ultimo_nivel_proximo.pop(obj, None)

        for obj in objetos_detectados:
            if obj not in em_confirmacao:
                em_confirmacao[obj] = tempo_atual

        novos_objetos = []

        for obj, primeiro_visto in em_confirmacao.items():
            nivel, t_confirmacao, t_reaviso, _ = PRIORIDADES.get(obj, PRIORIDADE_PADRAO)
            posicao, _, nivel_prox = objetos_detectados[obj]
            estavel     = (tempo_atual - primeiro_visto) >= t_confirmacao
            nao_recente = obj not in ultimo_aviso or (tempo_atual - ultimo_aviso[obj]) > t_reaviso

            if estavel and nao_recente:
                prefixo = {2: "Atenção! ", 1: "Atenção, "}.get(nivel_prox, "")
                sufixo  = sufixo_proximidade(nivel_prox, obj)
                novos_objetos.append((nivel, f"{prefixo}{obj}{sufixo} {posicao}"))
                ultimo_aviso[obj]         = tempo_atual
                ultimo_nivel_proximo[obj] = nivel_prox

            elif estavel and nivel_prox > ultimo_nivel_proximo.get(obj, 0):
                prefixo = {2: "Atenção! ", 1: "Atenção, "}.get(nivel_prox, "")
                sufixo  = sufixo_proximidade(nivel_prox, obj)
                novos_objetos.append((nivel, f"{prefixo}{obj}{sufixo} {posicao}"))
                ultimo_aviso[obj]         = tempo_atual
                ultimo_nivel_proximo[obj] = nivel_prox

        novos_objetos.sort(key=lambda x: x[0])
        textos = [t for _, t in novos_objetos]

        # ✅ Só coloca na fila se ela estiver vazia (evita acúmulo)
        if textos and fila_fala.empty():
            msg = f"{textos[0]}." if len(textos) == 1 else f"{', '.join(textos[:-1])} e {textos[-1]}."
            fila_fala.put(msg)

        cv2.imshow("Assistente de Navegacao TCC", frame)
        cv2.setWindowTitle("Assistente de Navegacao TCC",
            f"Assistente TCC Breno | FPS: {fps:.1f} | Fila voz: {fila_fala.qsize()}")

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    fila_fala.put(None)  # encerra a thread de voz corretamente
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    iniciar_assistente()