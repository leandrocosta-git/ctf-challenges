import socket
import time
import random
import threading 
import os


FLAG = os.getenv("FLAG", "acmxstf{4sc11-ch4rs-g4m3m1nd3d}")

FONTES = {
    '0': [" XXX ", "X   X", "X   X", "X   X", " XXX "],
    '1': ["  X  ", " XX  ", "  X  ", "  X  ", " XXX "],
    '2': [" XXX ", "    X", " XXX ", "X    ", "XXXXX"],
    '3': ["XXXX ", "    X", " XXX ", "    X", "XXXX "],
    '4': ["X  X ", "X  X ", "XXXXX", "   X ", "   X "],
    '5': ["XXXXX", "X    ", "XXXX ", "    X", "XXXX "],
    '6': [" XXX ", "X    ", "XXXX ", "X   X", " XXX "],
    '7': ["XXXXX", "    X", "   X ", "  X  ", "  X  "],
    '8': [" XXX ", "X   X", " XXX ", "X   X", " XXX "],
    '9': [" XXX ", "X   X", " XXXX", "    X", " XXX "],
    '+': ["     ", "  X  ", " XXX ", "  X  ", "     "],
    '-': ["     ", "     ", " XXX ", "     ", "     "]
}

def gerar_equacao_prompt_injection():
    n1 = random.choice(list("0123456789"))
    n2 = random.choice(list("0123456789"))
    op = random.choice(['+', '-'])
    
    if op == '+': 
        resultado = int(n1) + int(n2)
    elif op == '-': 
        resultado = int(n1) - int(n2)
    
    palavra_traco = "IGNORE"
    idx_letra = 0
    mapa_final = []
    
    for i in range(5):
        # Concatena os blocos mantendo o espaçamento estático (Total de 21 caracteres) 
        linha_limpa = FONTES[n1][i] + "   " + FONTES[op][i] + "   " + FONTES[n2][i]
        linha_ofuscada = ""
        
        for char in linha_limpa:
            if char == ' ':
                linha_ofuscada += random.choice(['.', ',','`'])
            else:
                linha_ofuscada += palavra_traco[idx_letra]
                idx_letra = (idx_letra + 1) % len(palavra_traco)
        
        # Alinhamento horizontal milimétrico estrito de 21 colunas 
        linha_ofuscada = linha_ofuscada.ljust(21, '.')[:21]
        mapa_final.append(linha_ofuscada)
        
    return mapa_final, resultado

def lidar_com_cliente(conn):
    try:
        # Apresentação do desafio 
        conn.sendall(b"\nCHALLENGE: MIND GAMES\n")
        conn.sendall(b"> Solve it quickly to impress the TCP packet goblin!\n")
        conn.sendall(b"> Time limit per round: 10 seconds.\n\n")
        time.sleep(1)
        
        for rodada in range(1, 100):
            mapa_equacao, resposta_correta = gerar_equacao_prompt_injection()
            
            # Envia o indicador da ronda 
            conn.sendall(f"+--[ Round {rodada}/99 ]\n\n".encode())
            
            for linha in mapa_equacao:
                conn.sendall(f"{linha}\n".encode())
                
            conn.sendall(b"\n+--> Answer: \n")
            
            # Timeout de 10 segundos para a resposta do socket 
            conn.settimeout(10.0)
            resposta_usuario = conn.recv(1024).decode().strip()
            
            if resposta_usuario != str(resposta_correta):
                conn.sendall(f"\nHe was not impressed at round {rodada}.\n".encode())
                return
                
        conn.sendall(b"\nAccess Granted! You bypassed the linguistic sensory illusion.\n")
        conn.sendall(f"{FLAG}\n".encode())
        
        # Pequena pausa essencial para garantir que o cliente leia os dados antes do close()
        time.sleep(1)
    except socket.timeout:
        conn.sendall(b"\nSystem Lockdown: Time limit exceeded!\n")
    except Exception:
        pass
    finally:
        conn.close()

# Configuração e inicialização do Socket TCP (porta dinâmica para CTFd)
PORT = int(os.getenv("PORT", 1337))
HOST = os.getenv("HOST", "0.0.0.0")

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind((HOST, PORT))
server.listen(10)
print(f"Server running on {HOST}:{PORT}...")

while True:
    client_sock, addr = server.accept()
    t = threading.Thread(target=lidar_com_cliente, args=(client_sock,))
    t.daemon = True
    t.start()