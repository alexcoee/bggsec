# bggsec

**bggsec** é um Unified Tool Manager focado em Kali/Pentest. Ele organiza, instala, atualiza e ajuda a executar ferramentas de segurança a partir de um único menu em Bash.

> Projeto educacional, ideal para estudantes de CyberSecurity e para quem quer manter o ambiente de pentest organizado.

![Menu do bggsec](https://github.com/user-attachments/assets/422fc65f-2ee8-47f2-af8d-b59bbc864046)

## Ambiente recomendado

- **WSL 2** (Windows Subsystem for Linux) com **Kali Linux Rolling**.
- **Bash** e **Git** instalados.
- Acesso à internet para clonar/atualizar ferramentas.

> O script foi desenvolvido e testado no WSL 2 com Kali. Em ambientes diferentes (como macOS ou outras distros Linux) ele também funciona, desde que Bash e Git estejam disponíveis.

## Como instalar

```bash
git clone https://github.com/alexcoee/bggsec.git
cd bggsec
chmod +x bggsec.sh
./bggsec.sh
```

## Tutorial rápido

### 1. Menu principal

Ao executar `./bggsec.sh`, o menu mostra as opções principais:

1. **Lista de ferramentas** – mostra todas as ferramentas do TSV.
2. **Buscar por nome** – filtra por nome, categoria ou descrição.
3. **Instalar/Atualizar tudo** – clona ou faz `git pull` em todas as ferramentas com repositório válido.
4. **Instalados** – lista apenas as ferramentas já clonadas.
5. **Ajuda** – mostra o resumo de uso.
0. **Sair** – encerra o script.

Você pode digitar diretamente o **ID** de uma ferramenta, em qualquer tela que exiba a dica “Busca: digite o ID...”, para abrir a tela específica dela.

### 2. Listar e instalar uma ferramenta

1. Escolha `1` no menu principal para abrir a lista completa.
2. Anote o **ID** da ferramenta desejada.
3. Digite o ID (por exemplo `105`) para abrir a tela de detalhes.
4. Pressione `1` nessa tela e confirme com `s` para instalar/atualizar.

Internamente, o script clona o repositório em `bggsec-tools/<nome-da-ferramenta>`. Se já existir, ele faz `git pull --rebase --autostash`.

### 3. Executar uma ferramenta instalada

1. Abra a tela da ferramenta (via ID ou pelo menu “Instalados”).
2. Verifique o campo **Run** – ele mostra o comando que será executado.
3. Pressione `2` e confirme; o script entra no diretório da ferramenta e executa o comando definido.
4. Para sair, use `CTRL+C` dentro do processo iniciado.

> Dica: alguns repositórios não têm comando padrão (`-`). Nesses casos, abra a pasta (opção 3) e execute manualmente conforme a documentação da ferramenta.

### 4. Remover ou abrir pastas

- **Mostrar pasta (opção 3)**: imprime o caminho completo onde a ferramenta está instalada.
- **Remover (opção 4)**: pede confirmação e apaga o diretório da ferramenta dentro de `bggsec-tools`.

### 5. Atualizar tudo de uma vez

Escolha a opção `3` do menu principal → confirme com `s`. O script percorre todas as linhas do `data/tools.tsv`, clonando ou atualizando cada ferramenta se o repositório for válido.

## Dicas para WSL 2 + Kali

- Utilize um prompt do **Windows Terminal** ou **PowerShell** configurado para abrir o Kali (WSL 2).
- Mantenha o WSL 2 atualizado (`wsl --update`) para evitar problemas de rede ao clonar repositórios.
- Ferramentas de Wi-Fi que dependem de modo monitor/injeção podem não funcionar dentro do WSL 2; nesses casos, execute-as diretamente em uma VM ou máquina física com suporte.

## Estrutura de dados

As ferramentas são definidas em `data/tools.tsv` (tab-separated). Cada linha contém:

```
id    categoria    nome    dir    repo    run    desc
```

Você pode editar esse arquivo para adicionar ferramentas personalizadas. Use `safe_dirname()` como referência para nomes de diretório.

## Licença

Distribuído nos termos do repositório original. Consulte a licença incluída (quando disponível) ou entre em contato com os mantenedores para mais detalhes.
