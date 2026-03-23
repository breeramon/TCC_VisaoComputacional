import cv2

def testar_camera():
    # O número 0 geralmente representa a webcam padrão do notebook/PC.
    # Se você usar uma câmera externa, pode ser necessário mudar para 1 ou 2.
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("Erro: Não foi possível acessar a câmera.")
        return

    print("Câmera iniciada com sucesso! Pressione a tecla 'q' para sair.")

    while True:
        # Lê um frame da câmera a cada iteração do loop
        sucesso, frame = cap.read()

        if not sucesso:
            print("Erro: Não foi possível capturar a imagem.")
            break

        # Mostra o frame em uma janela chamada "Teste de Câmera - TCC"
        cv2.imshow("Teste de Câmera - TCC", frame)

        # Aguarda 1 milissegundo por um evento de teclado.
        # Se a tecla pressionada for 'q', o loop é interrompido.
        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("Encerrando o teste...")
            break

    # Libera os recursos da câmera e fecha a janela do sistema operacional
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    testar_camera()