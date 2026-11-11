# Guia de instalação — Insta Automation (AIVACS)

App de "comenta X que te envio no direct" para o Instagram da AIVACS e dos clientes.
Baseado no OpenReply (licença MIT), com painel em espanhol e instalação num servidor grátis da Oracle.

**Custo:** €0. **Tempo:** cerca de 1h30, a maior parte esperando.

**Você vai precisar de:**
- Um cartão de crédito ou débito, só para a Oracle confirmar sua identidade. Ela não cobra no plano grátis.
- Acesso ao painel onde está o DNS do domínio `aivacs.online` (o mesmo lugar onde foi configurado o `es.aivacs.online`).
- Um e-mail para enviar os links de login (o da AIVACS ou um Gmail).
- A conta do Facebook que vai ser dona do app da Meta.
- O Instagram da AIVACS como conta Profissional (Empresa ou Criador de conteúdo), para os testes.

---

## Já tem um VPS na Hostinger? Use este atalho

Com um VPS da Hostinger (ex.: KVM 1), **pule as Partes 2, 3 e 4** (as da Oracle) e faça assim:

- **Parte 5 (endereço):** hPanel → **Domínios** → `aivacs.online` → **DNS / Nameservers** → adicionar registro **A**, nome `auto`, apontando para o **IP do VPS** (aparece na lista de VPS do hPanel).
- **Parte 6 (e-mail):** com um e-mail da Hostinger, use servidor `smtp.hostinger.com`, porta `465`, o e-mail completo como usuário e a senha dele.
- **Parte 7 (instalar):** hPanel → **VPS** → **Gerenciar** → **Terminal do navegador**. Você já entra como administrador; cole o comando do passo 3 da Parte 7. Não precisa do Terminal do Mac nem do arquivo `.key`.
- **Firewall:** se em hPanel → VPS → **Segurança → Firewall** houver regras ativas, adicione as portas TCP `80` e `443`. Se não houver nenhuma regra, não precisa fazer nada.

O instalador confere antes se o VPS já tem algo usando as portas do site (outro site, n8n, painel). Se tiver, ele para sem mudar nada e mostra o que está lá.

### VPS com EasyPanel (o caso do VPS do sócio)

Se o VPS mostra **EasyPanel** na Visão geral do hPanel, **não use o instalador**: o app entra como um projeto dentro do EasyPanel, sem mexer no que já roda lá.

1. **DNS:** registro **A** `auto` → IP do VPS (como acima).
2. **EasyPanel** (hPanel → VPS → **Gerenciar painel**) → **Create project** → nome `insta`.
3. No projeto, **+ Service → Postgres**, nome `db`. Depois **+ Service → Redis**, nome `redis`.
4. **+ Service → App**, nome `app`:
   - **Source → Git:** `https://github.com/jonatascne-droid/Insta-Automation.git`, branch `main`. **Build:** Dockerfile (`Dockerfile`).
   - **Environment:** no Web console do VPS, rode o comando abaixo, responda as perguntas e cole o bloco que ele mostrar:
     ```
     curl -fsSL https://raw.githubusercontent.com/jonatascne-droid/Insta-Automation/main/deploy/aivacs/easypanel-env.sh -o easypanel-env.sh && bash easypanel-env.sh
     ```
   - **Domains:** `auto.aivacs.online`, HTTPS ligado, porta `3000`.
   - **Deploy.** Um único serviço já roda as migrações do banco, o painel, o envio de DMs e a renovação de tokens.
5. Depois do app da Meta (Parte 8), cole os 3 valores dela nas linhas `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET` e `FACEBOOK_APP_SECRET` da aba **Environment** e clique em **Deploy** de novo.

## Parte 1 — Deixar o repositório público

O servidor baixa o código do GitHub sem senha. No repositório não fica nenhuma senha nem dado de cliente: tudo isso fica só no servidor.

1. Abra github.com/jonatascne-droid/Insta-Automation → **Settings**.
2. Desça até **Danger Zone** → **Change visibility** → **Public** → confirme.

> Se preferir manter privado, me avise: dá para fazer, mas o servidor precisa de uma chave de acesso e são mais alguns passos.

## Parte 2 — Criar a conta grátis na Oracle Cloud

1. Entre em **oracle.com/cloud/free** → **Start for free**.
2. Preencha os dados. Em **Home Region**, escolha **Spain Central (Madrid)**. Essa escolha não pode ser trocada depois.
3. Confirme o cartão. A Oracle faz uma reserva pequena e devolve.
4. Espere o e-mail dizendo que a conta está pronta (de alguns minutos a algumas horas).

> Não clique em "Upgrade to Pay As You Go" agora. No plano grátis não existe cobrança.

## Parte 3 — Criar o servidor

1. No painel da Oracle: menu **☰** → **Compute** → **Instances** → **Create instance**.
2. **Name:** `insta-automation`.
3. **Image and shape** → **Edit**:
   - **Image** → **Change image** → **Canonical Ubuntu** → versão **24.04** → **Select image**.
   - **Shape** → **Change shape** → **Ampere** → **VM.Standard.A1.Flex** → **1 OCPU** e **6 GB** de memória → **Select shape**. Precisa aparecer o selo "Always Free-eligible".
4. **Networking:** deixe como está. Confira que **Assign a public IPv4 address** está marcado.
5. **Add SSH keys:** escolha **Generate a key pair for me** → clique em **Save private key**. O arquivo (termina em `.key`) vai para a pasta Downloads. **Não perca esse arquivo**: é a chave do servidor.
6. Clique em **Create**. Espere o status ficar verde (**Running**).
7. Copie o **Public IP address** (algo como `152.70.12.34`). Vamos chamar de **IP DO SERVIDOR**.

> Se aparecer **"Out of capacity"**: mude o **Availability domain** (se houver mais de um) ou tente de novo mais tarde. É comum na Oracle e costuma resolver em algumas horas.

## Parte 4 — Liberar as portas do site na Oracle

1. Na página do servidor, clique no nome da **Subnet** (em *Primary VNIC*).
2. Abra **Security** (ou **Security Lists**) → **Default Security List**.
3. **Add Ingress Rules**:
   - **Source CIDR:** `0.0.0.0/0`
   - **IP Protocol:** `TCP`
   - **Destination Port Range:** `80,443`
4. **Add Ingress Rules** para salvar.

## Parte 5 — Criar o endereço auto.aivacs.online

No painel do DNS do domínio `aivacs.online`, crie um registro:

| Tipo | Nome | Valor |
|---|---|---|
| A | `auto` | IP DO SERVIDOR |

Salve. Leva de 5 a 30 minutos para funcionar.

## Parte 6 — E-mail para o login

O painel não tem senha: você digita o e-mail e recebe um link para entrar. Escolha uma opção e anote os dados:

- **E-mail da AIVACS** (do seu provedor de hospedagem): servidor SMTP, porta **465**, usuário (o e-mail completo) e senha.
- **Gmail:** ative a verificação em duas etapas na conta Google. Depois crie uma senha de app em **myaccount.google.com/apppasswords**. Os dados são: servidor `smtp.gmail.com`, porta `465`, usuário = o Gmail, senha = a senha de app de 16 letras.

## Parte 7 — Instalar o app no servidor (Terminal do Mac)

1. Abra o Terminal: **Cmd + Espaço**, digite `Terminal`, **Enter**.
2. Cole estes dois comandos, um de cada vez, trocando `IP_DO_SERVIDOR`:
   ```
   chmod 600 ~/Downloads/ssh-key-*.key
   ssh -i ~/Downloads/ssh-key-*.key ubuntu@IP_DO_SERVIDOR
   ```
   Na primeira vez ele pergunta `Are you sure you want to continue connecting?`: digite `yes` e **Enter**.
3. Agora você está dentro do servidor. Cole:
   ```
   curl -fsSL https://raw.githubusercontent.com/jonatascne-droid/Insta-Automation/main/deploy/aivacs/instalar.sh -o instalar.sh && bash instalar.sh
   ```
4. Responda as perguntas:
   - **Endereço do app:** Enter (`auto.aivacs.online`).
   - **E-mails que podem entrar:** o seu e o de quem mais da AIVACS for usar, separados por vírgula.
   - **Dados do SMTP:** os da Parte 6. A senha não aparece enquanto você digita, é normal.
5. Espere de 5 a 15 minutos. No fim aparece **PRONTO** e três dados para a Meta. **Copie e guarde** esses três dados.

## Parte 8 — Criar o app da Meta

1. Entre em **developers.facebook.com** → **Meus apps** → **Criar app**. Se for a primeira vez, ele pede para você se registrar como desenvolvedor.
2. **Caso de uso:** filtre por **Todos** e escolha **Gerenciar mensagens e conteúdo no Instagram**. Não escolha "Marketing API" nem "Login do Facebook".
3. Se pedir, ligue o app ao portfólio empresarial da AIVACS.
4. No app: **Instagram** → **Configuração da API com login do Instagram**:
   - Anote o **ID do app do Instagram** e a **Chave secreta do app do Instagram** (clique em Mostrar).
   - Em **Configurações do app** → **Básico**, anote a **Chave secreta do app**.
   - No Terminal (ainda conectado ao servidor), rode e cole os três valores:
     ```
     sudo bash /opt/insta-automation/deploy/aivacs/configurar-meta.sh
     ```
5. **Configurar webhooks** (na mesma página do Instagram):
   - **URL de callback:** `https://auto.aivacs.online/api/webhook`
   - **Token de verificação:** o que o instalador mostrou.
   - **Verificar e salvar**. Depois ative os campos **comments** e **messages**.
6. **Configurar login empresarial do Instagram** → **URIs de redirecionamento do OAuth:**
   `https://auto.aivacs.online/api/instagram/callback`
7. **Configurações do app → Básico:**
   - Política de privacidade: `https://auto.aivacs.online/privacy`
   - Termos de serviço: `https://auto.aivacs.online/terms`
   - Exclusão de dados: `https://auto.aivacs.online/data-deletion`
   - Categoria e ícone do app. Salve.
8. **Funções do app → Funções → Testadores do Instagram** → adicione o @ da AIVACS.
   Depois, no **Instagram da AIVACS** (no celular): Perfil → ☰ → **Configurações e atividade** → **Apps e sites** → **Convites de testador** → **Aceitar**.
9. **Publicar** (menu da esquerda) → publique o app. Sem isso, os comentários reais não chegam.

## Parte 9 — Testar

1. Abra **https://auto.aivacs.online**, digite seu e-mail e clique no link que chegar.
2. **Ajustes** → **Conectar Instagram** → entre com o Instagram da AIVACS e aceite tudo.
3. Crie uma campanha: palavra-chave `QUIERO` e uma mensagem com um link.
4. Com outra conta do Instagram, comente `QUIERO` num post da AIVACS. A DM chega em segundos.

## Parte 10 — Conectar um cliente

1. O Instagram do cliente precisa ser **Profissional** (Empresa ou Criador de conteúdo).
2. No app da Meta: **Funções do app → Testadores do Instagram** → adicione o @ do cliente. O cliente aceita o convite no Instagram dele (mesmo caminho da Parte 8, passo 8).
3. No painel: **Ajustes → Conectar Instagram** → o cliente faz o login dele nessa tela. Dá para fazer junto com ele numa chamada.
4. Se o cliente já usou ManyChat ou outra ferramenta de DM: **Meta Business Suite → Configurações → Integrações → Roteamento de conversas** → remova o app antigo e dê controle das conversas para este app.

> Enquanto o app não passar pela revisão da Meta, cada cliente entra como testador (passo 2). A revisão, que deixa o cliente conectar sozinho, exige a verificação da empresa AIVACS e uma política de privacidade com os dados da AIVACS. Fazemos isso depois.

**Regras do Instagram:** 1 DM por comentário, enviada em até 7 dias depois do comentário, até 750 por hora por conta. A DM precisa ser o que a pessoa pediu no comentário.

---

## No dia a dia

- **Atualização automática:** a cada 10 minutos o servidor confere o GitHub. Quando eu publicar melhorias, ele se atualiza sozinho.
- **Backup:** todo dia às 03:30, os últimos 7 dias ficam em `/opt/insta-automation-backups`.
- **Ver se está tudo rodando** (conectado ao servidor):
  ```
  cd /opt/insta-automation/deploy/aivacs && sudo docker compose ps
  ```
- **Ver o que o worker está fazendo:**
  ```
  cd /opt/insta-automation/deploy/aivacs && sudo docker compose logs --tail 50 worker
  ```
- **Liberar o login para outro e-mail:** edite a linha `ALLOWED_EMAILS` com
  `sudo nano /opt/insta-automation/deploy/aivacs/.env` e rode `sudo bash /opt/insta-automation/deploy/aivacs/atualizar.sh --forcar`.

> **Aviso da Oracle:** no plano grátis, a Oracle pode desligar servidores que ficam quase parados por 7 dias seguidos. Por isso usamos 1 OCPU e 6 GB, para o uso não ficar baixo demais. Se receber um e-mail da Oracle sobre isso, ligue o servidor de novo no painel (**Start**): os dados continuam lá. Para eliminar esse risco de vez, dá para mudar a conta para "Pay As You Go" com um alerta de orçamento de €1. Os recursos grátis continuam grátis.
