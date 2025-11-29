# GUIA COMPLETO DE DEPLOY - SISTEMA ELEGÂNCIA PREMIUM

## 📋 Índice
1. Preparação do Ambiente
2. Instalação do Banco de Dados
3. Configuração da Aplicação
4. Testes Pré-Deploy
5. Deploy em Produção
6. Pós-Deploy e Monitoramento

---

## 1️⃣ PREPARAÇÃO DO AMBIENTE

### 1.1 Requisitos de Sistema

**Hardware Mínimo:**
- CPU: 2 cores
- RAM: 4GB
- Armazenamento: 50GB
- Conexão: 10Mbps

**Sistema Operacional:**
- Ubuntu 20.04 LTS (recomendado)
- CentOS 8+
- Windows Server 2019+
- macOS 10.15+

### 1.2 Instalação de Dependências (Ubuntu/Debian)

```bash
# Atualizar repositórios
sudo apt-get update
sudo apt-get upgrade -y

# Instalar Python 3.9
sudo apt-get install -y python3.9 python3.9-venv python3-pip

# Instalar MySQL Server
sudo apt-get install -y mysql-server mysql-client

# Instalar desenvolvimento
sudo apt-get install -y build-essential libmysqlclient-dev

# Verificar instalações
python3.9 --version
mysql --version
```

### 1.3 Instalação de Dependências (CentOS/RHEL)

```bash
# Instalar Python 3.9
sudo yum install -y python39 python39-devel

# Instalar MySQL
sudo yum install -y mysql-server mysql-client mysql-devel

# Iniciar MySQL
sudo systemctl start mysqld
sudo systemctl enable mysqld
```

### 1.4 Instalação de Dependências (macOS)

```bash
# Usar Homebrew
brew install python@3.9
brew install mysql

# Verificar instalações
python3.9 --version
mysql --version
```

---

## 2️⃣ INSTALAÇÃO DO BANCO DE DADOS

### 2.1 Iniciar Serviço MySQL

**Ubuntu/Debian:**
```bash
sudo systemctl start mysql
sudo systemctl enable mysql
```

**macOS (via Homebrew):**
```bash
brew services start mysql
```

**Windows:**
```cmd
# Abrir Services e iniciar MySQL80
net start MySQL80
```

### 2.2 Verificar Conexão

```bash
mysql -u root -p
# Digite a senha do root
```

Se conectar com sucesso, sair:
```sql
EXIT;
```

### 2.3 Criar Banco de Dados

```bash
# Opção 1: Executar arquivo SQL direto
mysql -u root -p < elegancia_premium.sql

# Opção 2: Manualmente
mysql -u root -p
```

```sql
-- Se usar opção 2, dentro do MySQL:
SOURCE /caminho/para/elegancia_premium.sql;

-- Verificar se foi criado
SHOW DATABASES;
USE elegancia_premium;
SHOW TABLES;
```

### 2.4 Criar Usuário MySQL para Aplicação

```sql
-- Criar usuário
CREATE USER 'elegancia'@'localhost' IDENTIFIED BY 'senha_super_segura_2025';

-- Conceder permissões
GRANT ALL PRIVILEGES ON elegancia_premium.* TO 'elegancia'@'localhost';

-- Aplicar mudanças
FLUSH PRIVILEGES;

-- Verificar
SELECT User, Host FROM mysql.user WHERE User='elegancia';
```

### 2.5 Configurar Backup Automático

**Linux/macOS (cron):**
```bash
# Editar crontab
crontab -e

# Adicionar linha para backup diário às 23:00
0 23 * * * /home/user/scripts/backup.sh
```

**Criar script de backup (backup.sh):**
```bash
#!/bin/bash
BACKUP_DIR="/backups/elegancia_premium"
DATE=$(date +%Y%m%d_%H%M%S)
FILENAME="elegancia_premium_$DATE.sql"

# Criar diretório se não existir
mkdir -p $BACKUP_DIR

# Fazer backup
mysqldump -u elegancia -p'senha_super_segura_2025' elegancia_premium > $BACKUP_DIR/$FILENAME

# Comprimir
gzip $BACKUP_DIR/$FILENAME

# Manter apenas últimos 30 dias
find $BACKUP_DIR -type f -mtime +30 -delete

echo "Backup realizado: $BACKUP_DIR/$FILENAME.gz"
```

**Tornar executável:**
```bash
chmod +x /home/user/scripts/backup.sh
```

---

## 3️⃣ CONFIGURAÇÃO DA APLICAÇÃO

### 3.1 Clonar/Baixar Projeto

```bash
# Opção 1: Git
git clone <url-do-repositorio> /app/elegancia-premium
cd /app/elegancia-premium

# Opção 2: Upload manual
# Descompactar arquivo .zip na pasta /app/elegancia-premium
```

### 3.2 Criar Ambiente Virtual

```bash
# Navegar para diretório do projeto
cd /app/elegancia-premium

# Criar virtual environment
python3.9 -m venv venv

# Ativar ambiente (Linux/macOS)
source venv/bin/activate

# Ativar ambiente (Windows)
venv\Scripts\activate
```

### 3.3 Instalar Dependências Python

```bash
# Com ambiente virtual ativado
pip install --upgrade pip
pip install -r requirements.txt
```

### 3.4 Configurar Variáveis de Ambiente

**Criar arquivo .env:**
```bash
# Na pasta raiz do projeto
cat > .env << EOF
FLASK_ENV=production
FLASK_DEBUG=False
FLASK_SECRET_KEY=sua_chave_secreta_super_segura_aqui_2025
MYSQL_HOST=localhost
MYSQL_USER=elegancia
MYSQL_PASSWORD=senha_super_segura_2025
MYSQL_DB=elegancia_premium
EOF
```

**Alternativa: Editar app.py diretamente**

```python
# Localizar seção CONFIGURAÇÃO DA APLICAÇÃO
app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_USER'] = 'elegancia'
app.config['MYSQL_PASSWORD'] = 'senha_super_segura_2025'
app.config['MYSQL_DB'] = 'elegancia_premium'
```

### 3.5 Testar Execução Local

```bash
# Com venv ativado
python app.py

# Saída esperada:
# * Running on http://0.0.0.0:5000
# * Press CTRL+C to quit
```

**Acessar:** http://localhost:5000

**Fazer login:**
- Email: maria@elegancia.com
- Senha: senha123

---

## 4️⃣ TESTES PRÉ-DEPLOY

### 4.1 Teste de Conectividade com BD

```bash
# Criar script de teste
cat > test_db.py << 'EOF'
import MySQLdb
from app import app, mysql

try:
    cursor = mysql.connection.cursor()
    cursor.execute("SELECT COUNT(*) FROM usuarios")
    resultado = cursor.fetchone()
    cursor.close()
    
    print("✅ Conexão com banco bem-sucedida!")
    print(f"   Usuários cadastrados: {resultado[0]}")
except Exception as e:
    print(f"❌ Erro de conexão: {e}")
EOF

# Executar teste
python test_db.py
```

### 4.2 Teste de Login

```bash
# Criar script de teste
cat > test_login.py << 'EOF'
import requests
from flask import Flask
from app import app

client = app.test_client()

# Teste 1: Página de login acessível
print("Teste 1: Acessar página de login...")
response = client.get('/login')
assert response.status_code == 200
print("✅ Página de login ok")

# Teste 2: Login com credenciais corretas
print("\nTeste 2: Login com credenciais corretas...")
response = client.post('/login', data={
    'email': 'maria@elegancia.com',
    'senha': 'senha123'
})
assert response.status_code == 200 or response.status_code == 302
print("✅ Login ok")

# Teste 3: Acesso a recurso protegido sem autenticação
print("\nTeste 3: Recurso protegido sem autenticação...")
response = client.get('/dashboard')
assert response.status_code == 302  # Redireciona para login
print("✅ Proteção de recurso ok")

print("\n✅ Todos os testes passaram!")
EOF

# Executar testes
python test_login.py
```

### 4.3 Teste de API

```bash
# Criar script de teste
cat > test_api.py << 'EOF'
import requests
from app import app

client = app.test_client()

# Fazer login primeiro
session = requests.Session()
session.post('http://localhost:5000/login', data={
    'email': 'maria@elegancia.com',
    'senha': 'senha123'
})

# Teste 1: Obter clientes
print("Teste 1: Obter clientes...")
response = session.get('http://localhost:5000/api/clientes')
assert response.status_code == 200
print(f"✅ {len(response.json())} clientes retornados")

# Teste 2: Obter estoque
print("\nTeste 2: Obter estoque...")
response = session.get('http://localhost:5000/api/estoque')
assert response.status_code == 200
print(f"✅ Estoque ok")

print("\n✅ APIs funcionando!")
EOF

# Executar testes
python test_api.py
```

---

## 5️⃣ DEPLOY EM PRODUÇÃO

### 5.1 Deploy com Gunicorn

**Instalar Gunicorn:**
```bash
pip install gunicorn
```

**Executar aplicação:**
```bash
# Básico (single worker)
gunicorn -w 1 -b 127.0.0.1:5000 app:app

# Recomendado (múltiplos workers)
gunicorn -w 4 -b 127.0.0.1:5000 --timeout 120 app:app

# Com arquivo de configuração
gunicorn -c gunicorn_config.py app:app
```

**Criar arquivo de configuração (gunicorn_config.py):**
```python
import multiprocessing

# Configurações
bind = "127.0.0.1:5000"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
timeout = 120
keepalive = 5
accesslog = "/var/log/elegancia/access.log"
errorlog = "/var/log/elegancia/error.log"
loglevel = "info"
```

### 5.2 Configurar Nginx Reverse Proxy

**Instalar Nginx:**
```bash
sudo apt-get install -y nginx
```

**Criar configuração (elegancia_premium.conf):**
```nginx
upstream elegancia_app {
    server 127.0.0.1:5000;
}

server {
    listen 80;
    server_name seu_dominio.com www.seu_dominio.com;
    
    # Redirecionar HTTP para HTTPS (opcional)
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name seu_dominio.com www.seu_dominio.com;
    
    # Certificados SSL
    ssl_certificate /etc/ssl/certs/seu_dominio.crt;
    ssl_certificate_key /etc/ssl/private/seu_dominio.key;
    
    # Configurações SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Logs
    access_log /var/log/nginx/elegancia_access.log;
    error_log /var/log/nginx/elegancia_error.log;
    
    # Limite de upload
    client_max_body_size 10M;
    
    location / {
        proxy_pass http://elegancia_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }
    
    location /static {
        alias /app/elegancia-premium/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

**Ativar configuração:**
```bash
# Criar link simbólico
sudo ln -s /etc/nginx/sites-available/elegancia_premium.conf /etc/nginx/sites-enabled/

# Testar configuração
sudo nginx -t

# Reiniciar Nginx
sudo systemctl restart nginx
```

### 5.3 Usar Systemd para Iniciar Automaticamente

**Criar arquivo de serviço:**
```bash
sudo cat > /etc/systemd/system/elegancia-premium.service << 'EOF'
[Unit]
Description=Elegancia Premium Flask Application
After=network.target

[Service]
Type=notify
User=www-data
WorkingDirectory=/app/elegancia-premium
Environment="PATH=/app/elegancia-premium/venv/bin"
ExecStart=/app/elegancia-premium/venv/bin/gunicorn -c /app/elegancia-premium/gunicorn_config.py app:app
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=mixed
KillSignal=SIGTERM
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
```

**Ativar serviço:**
```bash
# Recarregar daemon
sudo systemctl daemon-reload

# Ativar na inicialização
sudo systemctl enable elegancia-premium

# Iniciar serviço
sudo systemctl start elegancia-premium

# Verificar status
sudo systemctl status elegancia-premium
```

### 5.4 Configurar SSL com Let's Encrypt

**Instalar Certbot:**
```bash
sudo apt-get install -y certbot python3-certbot-nginx
```

**Gerar certificado:**
```bash
sudo certbot certonly --nginx -d seu_dominio.com -d www.seu_dominio.com
```

---

## 6️⃣ PÓS-DEPLOY E MONITORAMENTO

### 6.1 Verificações Pós-Deploy

```bash
# Verificar serviço rodando
sudo systemctl status elegancia-premium

# Verificar porta Nginx
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Verificar logs
tail -f /var/log/elegancia/access.log
tail -f /var/log/elegancia/error.log

# Testar conectividade
curl -I https://seu_dominio.com

# Teste de login
curl -X POST https://seu_dominio.com/login \
     -d "email=maria@elegancia.com&senha=senha123"
```

### 6.2 Monitoramento Contínuo

**Script de health check (health_check.sh):**
```bash
#!/bin/bash

DOMAIN="seu_dominio.com"
EMAIL="admin@seu_dominio.com"

# Verificar se aplicação está respondendo
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN)

if [ $HTTP_CODE -ne 200 ]; then
    echo "❌ Aplicação indisponível! HTTP: $HTTP_CODE"
    echo "Tentando reiniciar..."
    sudo systemctl restart elegancia-premium
    
    # Enviar alerta por email
    echo "Aplicação foi reiniciada em $(date)" | mail -s "Alerta: Elegância Premium" $EMAIL
else
    echo "✅ Aplicação ok (HTTP: $HTTP_CODE)"
fi
```

**Adicionar ao cron (a cada 5 minutos):**
```bash
*/5 * * * * /home/user/scripts/health_check.sh >> /var/log/elegancia/health_check.log
```

### 6.3 Logs Importantes

**Monitorar:**
- `/var/log/nginx/elegancia_access.log` - Requisições HTTP
- `/var/log/nginx/elegancia_error.log` - Erros Nginx
- `/var/log/elegancia/access.log` - Logs da app
- `/var/log/elegancia/error.log` - Erros da app
- `/var/log/mysql/error.log` - Erros do MySQL

**Analisar logs (exemplo):**
```bash
# Ver últimas 100 linhas
tail -100 /var/log/elegancia/access.log

# Ver logs em tempo real
tail -f /var/log/elegancia/access.log

# Procurar por erros
grep ERROR /var/log/elegancia/error.log | tail -50

# Contar requisições por hora
cat /var/log/nginx/elegancia_access.log | cut -d' ' -f4 | cut -d: -f1-2 | sort | uniq -c
```

### 6.4 Escalonamento Futuro

**Quando adicionar mais workers:**
```python
# gunicorn_config.py
workers = 8  # Aumentar de 4 para 8
worker_class = "gevent"  # Para maior concorrência
```

**Adicionar cache (Redis) - futuro:**
```bash
sudo apt-get install -y redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

---

## 🎯 Checklist de Deploy

- [ ] Servidor preparado (Python, MySQL)
- [ ] Banco de dados criado e testado
- [ ] Aplicação clonada/baixada
- [ ] Virtual environment criado
- [ ] Dependências instaladas
- [ ] Variáveis de ambiente configuradas
- [ ] Testes executados com sucesso
- [ ] Gunicorn testado localmente
- [ ] Nginx configurado
- [ ] SSL configurado (Let's Encrypt)
- [ ] Systemd service criado
- [ ] Backup automático configurado
- [ ] Health check configurado
- [ ] Logs monitorados
- [ ] Equipe treinada
- [ ] Go-live autorizado

---

**Suporte:** Em caso de dúvidas, consultar documentação técnica ou contatar equipe de desenvolvimento.

