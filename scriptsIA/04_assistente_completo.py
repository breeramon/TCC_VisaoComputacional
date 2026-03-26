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

def calcular_posicao(x1, x2, largura_frame):
    """Retorna 'à sua esquerda', 'à sua frente' ou 'à sua direita'
    com base no centro horizontal da bounding box."""
    centro_obj = (x1 + x2) / 2
    terco = largura_frame / 3
    if centro_obj < terco:
        return 'à sua esquerda'
    elif centro_obj < 2 * terco:
        return 'à sua frente'
    else:
        return 'à sua direita'

# Limiares de proximidade (fração da área total do frame ocupada pela bounding box)
LIMIAR_PROXIMO       = 0.15  # > 15% do frame = próximo
LIMIAR_MUITO_PROXIMO = 0.30  # > 30% do frame = muito próximo

def calcular_proximidade(area_box, area_frame):
    """Retorna o nível de proximidade: 0=normal, 1=próximo, 2=muito próximo."""
    ratio = area_box / area_frame
    if ratio >= LIMIAR_MUITO_PROXIMO:
        return 2
    elif ratio >= LIMIAR_PROXIMO:
        return 1
    return 0

# Gênero gramatical de cada classe (para concordância dos adjetivos)
GENERO = {
    'Porta':                'f',
    'Elevador':             'm',
    'Extintor de incêndio': 'm',
    'Lixeira':              'f',
    'Bebedouro':            'm',
    'Pessoa':               'f',
    'Placa de escada':      'f',
    'Sinalização de saída': 'f',
}

def sufixo_proximidade(nivel_prox, obj):
    """Retorna o sufixo de proximidade concordando com o gênero do objeto."""
    genero = GENERO.get(obj, 'm')
    if nivel_prox == 2:
        return ' muito próxima' if genero == 'f' else ' muito próximo'
    elif nivel_prox == 1:
        return ' próxima' if genero == 'f' else ' próximo'
    return ''

# 2. Tabela de prioridades por classe
# Estrutura: nome_traduzido -> (nivel, tempo_confirmacao, tempo_reaviso, cor_bgr)
#   nivel 1 = alta prioridade (obstáculos dinâmicos)
#   nivel 2 = média prioridade (pontos de navegação)
#   nivel 3 = baixa prioridade (pontos de referência)
PRIORIDADES = {
    'Pessoa':                 (1, 0.4, 3.0, (0, 0, 255)),    # vermelho
    'Porta':                  (2, 0.8, 5.0, (0, 165, 255)),  # laranja
    'Elevador':               (2, 0.8, 5.0, (0, 165, 255)),  # laranja
    'Placa de escada':        (2, 0.8, 5.0, (0, 165, 255)),  # laranja
    'Sinalização de saída':   (2, 0.8, 5.0, (0, 165, 255)),  # laranja
    'Extintor de incêndio':   (3, 1.0, 8.0, (0, 255, 0)),    # verde
    'Lixeira':                (3, 1.0, 8.0, (0, 255, 0)),    # verde
    'Bebedouro':              (3, 1.0, 8.0, (0, 255, 0)),    # verde
}
PRIORIDADE_PADRAO = (3, 1.0, 8.0, (0, 255, 0))

# 3. Criando a Fila de comunicação
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

    em_confirmacao      = {}  # obj -> timestamp da primeira detecção contínua
    ultimo_aviso        = {}  # obj -> timestamp do último anúncio normal
    ultimo_nivel_proximo = {}  # obj -> último nível de proximidade anunciado (0, 1 ou 2)

    while True:
        ret, frame = cap.read()
        if not ret:
            print("ERRO: O Iriun está conectado, mas a imagem do celular falhou.")
            break

        largura_frame = frame.shape[1]
        area_frame    = frame.shape[0] * frame.shape[1]
        resultados = modelo(frame, conf=0.6, stream=True)
        # Guarda {nome: (posicao, area, nivel_proximidade)} — mantém o maior se o mesmo objeto aparecer duas vezes
        objetos_detectados = {}

        for r in resultados:
            boxes = r.boxes
            for box in boxes:
                classe_id = int(box.cls[0])
                nome_original = modelo.names[classe_id]
                nome_traduzido = traducao_classes.get(nome_original, nome_original)

                x1, y1, x2, y2 = map(int, box.xyxy[0])
                posicao   = calcular_posicao(x1, x2, largura_frame)
                area      = (x2 - x1) * (y2 - y1)
                nivel_prox = calcular_proximidade(area, area_frame)

                if nome_traduzido not in objetos_detectados or area > objetos_detectados[nome_traduzido][1]:
                    objetos_detectados[nome_traduzido] = (posicao, area, nivel_prox)

                # Espessura da bounding box aumenta conforme proximidade
                espessura = 2 + nivel_prox * 2  # 2, 4 ou 6
                _, _, _, cor = PRIORIDADES.get(nome_traduzido, PRIORIDADE_PADRAO)
                cv2.rectangle(frame, (x1, y1), (x2, y2), cor, espessura)
                label = f"{nome_traduzido} ({posicao})"
                cv2.putText(frame, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, cor, 2)

        tempo_atual = time.time()

        # Remove da confirmação objetos que saíram do frame (reset dos timers)
        for obj in list(em_confirmacao.keys()):
            if obj not in objetos_detectados:
                del em_confirmacao[obj]
                ultimo_nivel_proximo.pop(obj, None)

        # Registra o momento em que cada objeto apareceu pela primeira vez nesta janela
        for obj in objetos_detectados:
            if obj not in em_confirmacao:
                em_confirmacao[obj] = tempo_atual

        # Monta lista de anúncios: objetos novos + alertas de proximidade crescente
        novos_objetos = []  # lista de (nivel_prioridade, texto_anuncio)

        for obj, primeiro_visto in em_confirmacao.items():
            nivel, t_confirmacao, t_reaviso, _ = PRIORIDADES.get(obj, PRIORIDADE_PADRAO)
            posicao, _, nivel_prox = objetos_detectados[obj]
            estavel     = (tempo_atual - primeiro_visto) >= t_confirmacao
            nao_recente = obj not in ultimo_aviso or (tempo_atual - ultimo_aviso[obj]) > t_reaviso

            # Anúncio normal (primeira detecção estável ou reaviso periódico)
            if estavel and nao_recente:
                prefixo = {2: "Atenção! ", 1: "Atenção, "}.get(nivel_prox, "")
                sufixo  = sufixo_proximidade(nivel_prox, obj)
                novos_objetos.append((nivel, f"{prefixo}{obj}{sufixo} {posicao}"))
                ultimo_aviso[obj]         = tempo_atual
                ultimo_nivel_proximo[obj] = nivel_prox

            # Alerta extra: proximidade aumentou desde o último anúncio
            elif estavel and nivel_prox > ultimo_nivel_proximo.get(obj, 0):
                prefixo = {2: "Atenção! ", 1: "Atenção, "}.get(nivel_prox, "")
                sufixo  = sufixo_proximidade(nivel_prox, obj)
                novos_objetos.append((nivel, f"{prefixo}{obj}{sufixo} {posicao}"))
                ultimo_aviso[obj]         = tempo_atual
                ultimo_nivel_proximo[obj] = nivel_prox

        # Ordena por prioridade (1=alta primeiro) antes de anunciar
        novos_objetos.sort(key=lambda x: x[0])
        textos = [texto for _, texto in novos_objetos]

        if textos:
            if len(textos) == 1:
                fila_fala.put(f"{textos[0]}.")
            else:
                fila_fala.put(f"{', '.join(textos[:-1])} e {textos[-1]}.")

        cv2.imshow("Assistente de Navegacao TCC", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    iniciar_assistente()