import pyttsx3

def testar_voz():
    print("Iniciando o motor de voz...")
    engine = pyttsx3.init()

    # Configurando a velocidade da fala (Rate) - 220 é um bom padrão
    engine.setProperty('rate', 210)

    # Procurando uma voz em Português
    voices = engine.getProperty('voices')
    for voz in voices:
        if "Portuguese" in voz.name or "Brazil" in voz.name or "BR" in voz.id:
            engine.setProperty('voice', voz.id)
            print(f"Voz configurada para: {voz.name}")
            break

    texto = "Olá! Eu sou o assistente de navegação do seu TCC. O módulo de voz está funcionando perfeitamente."
    
    print(f"Dizendo: '{texto}'")
    engine.say(texto)
    
    # O comando abaixo faz o programa esperar a fala terminar antes de fechar
    engine.runAndWait()
    print("Teste finalizado.")

if __name__ == "__main__":
    testar_voz()