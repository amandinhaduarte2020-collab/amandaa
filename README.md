# Sistema Elegância Premium - Guia de Instalação e Uso

## 📋 Visão Geral

Sistema completo de gestão para a loja "Elegância Premium" desenvolvido com Flask e MySQL. Oferece controle de clientes, produtos, estoque, vendas e relatórios com interface responsiva e autenticação segura.

## 🚀 Instalação Rápida

### Pré-requisitos

- Python 3.9 ou superior
- MySQL 5.7 ou superior
- pip (gerenciador de pacotes Python)

### 1. Clonar ou Baixar o Projeto

```bash
git clone <url-do-repositorio>
cd elegancia-premium
```

### 2. Criar Ambiente Virtual

```bash
# No Windows
python -m venv venv
venv\Scripts\activate

# No macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

### 3. Instalar Dependências

```bash
pip install -r requirements.txt
```

### 4. Configurar Banco de Dados

#### 4.1 Criar Banco de Dados

```bash
# Abrir MySQL
mysql -u root -p

# Dentro do MySQL
SOURCE elegancia_premium.sql;
```

#### 4.2 Configurar Credenciais (app.py)

Editar o arquivo `app.py` e atualizar:

```python
app.config['MYSQL_USER'] = 'seu_usuario'
app.config['MYSQL_PASSWORD'] = 'sua_senha'
```

### 5. Executar Aplicação

```bash
python app.py
```

A aplicação estará disponível em: `http://localhost:5000`

## 🔐 Credenciais de Teste

**Gerente:**
- Email: maria@elegancia.com
- Senha: senha123
- Permissão: GERENTE (acesso total)

**Vendedor:**
- Email: carlos@elegancia.com
- Senha: senha123
- Permissão: VENDEDOR (vendas e consultas)

**Estoquista:**
- Email: patricia@elegancia.com
- Senha: senha123
- Permissão: ESTOQUISTA (estoque)

## 📁 Estrutura do Projeto

```
elegancia-premium/
├── app.py                    # Aplicação Flask principal
├── requirements.txt          # Dependências Python
├── elegancia_premium.sql     # Script do banco de dados
├── templates/                # Templates HTML
│   ├── base.html            # Template base
│   ├── login.html           # Login
│   ├── dashboard.html       # Dashboard principal
│   ├── clientes.html        # Gestão de clientes
│   ├── estoque.html         # Controle de estoque
│   ├── vendas.html          # Registro de vendas
│   └── relatorios.html      # Relatórios
└── static/
    ├── css/
    │   └── style.css        # Estilos
    ├── js/
    │   └── main.js          # Scripts
    └── img/                 # Imagens
```

## 🎯 Funcionalidades Principais

### 👥 Gestão de Clientes
- Cadastro completo de clientes (nome, CPF, email, telefone, endereço)
- Validação de CPF duplicado
- Histórico de compras
- Rastreamento de preferências

### 📦 Gerenciamento de Produtos
- Cadastro de coleções, produtos, cores e tamanhos
- Variações de produtos com SKU único
- Associação com fornecedores
- Filtragem e busca avançada

### 📊 Controle de Estoque
- Estoque em tempo real por variação
- Alertas de estoque baixo
- Histórico de movimentações
- Rastreabilidade completa

### 💳 Registro de Vendas
- Registro rápido de vendas
- Validação de estoque
- Aplicação automática de promoções
- Cálculo de desconto e total

### 🔄 Devoluções
- Registro de devoluções
- Reposição automática de estoque
- Cálculo de reembolso
- Histórico de devoluções

### 📈 Relatórios
- Vendas por período
- Vendas por vendedor
- Vendas por coleção
- Produtos mais vendidos
- Estoque baixo
- Auditoria completa

### 🔒 Segurança
- Autenticação por email/senha
- Senhas criptografadas com bcrypt
- Controle de permissões por papel
- Logs de auditoria de todas operações
- Validação de entrada (SQL injection, XSS)

## 🔧 Configuração Avançada

### Habilitar HTTPS em Produção

```python
# app.py
if __name__ == '__main__':
    app.run(ssl_context='adhoc')  # Requer pyopenssl
```

### Configurar Backup Automático

Adicionar cron job (Linux):

```bash
0 23 * * * mysqldump -u root -p elegancia_premium > /backup/elegancia_premium_$(date +%Y%m%d).sql
```

### Variáveis de Ambiente

Criar arquivo `.env`:

```
FLASK_ENV=production
FLASK_SECRET_KEY=sua_chave_super_secreta
MYSQL_USER=seu_usuario
MYSQL_PASSWORD=sua_senha
```

## 🐛 Troubleshooting

### Erro: "Connection refused"
- Verificar se MySQL está rodando
- Confirmar credenciais em `app.py`
- Verificar se banco de dados foi criado

### Erro: "No module named 'flask'"
```bash
pip install -r requirements.txt
```

### Erro: "ModuleNotFoundError: No module named 'MySQLdb'"
```bash
pip install flask-mysqldb
```

### Senhas de Teste Não Funcionam
- Gerar novo hash com bcrypt:
```python
from werkzeug.security import generate_password_hash
print(generate_password_hash('nova_senha'))
```
- Atualizar no banco de dados

## 📊 Banco de Dados

### Normalização: 3FN Completa

#### Tabelas Principais:
1. **usuarios** - Controle de acesso
2. **clientes** - Dados dos compradores
3. **colecoes** - Agrupamento de produtos
4. **fornecedores** - Cadastro de fornecedores
5. **produtos** - Catálogo
6. **cores** - Paleta de cores
7. **tamanhos** - Grade de tamanhos
8. **produto_variacao** - SKU com estoque
9. **vendas** - Transações
10. **item_venda** - Detalhes por venda
11. **promocoes** - Campanhas
12. **produto_promocao** - Associação
13. **devolucoes** - Registro de devoluções
14. **audit_log** - Auditoria completa

### Chaves e Índices
- Chave primária em todas as tabelas
- Índices em campos de busca frequente
- Chaves estrangeiras com integridade referencial
- UNIQUE em CPF, email, SKU

## 🚀 Deploy em Produção

### Com Gunicorn

```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

### Com Nginx (configuração)

```nginx
server {
    listen 80;
    server_name seu_dominio.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 📚 Documentação Adicional

Ver `Documentacao_Tecnica_Elegancia_Premium.pdf` para:
- Business Model Canvas completo
- Diagramas UML (Casos de Uso, Classes)
- Normalização do banco de dados
- Fluxos operacionais detalhados
- Requisitos Funcionais e Não-Funcionais
- Regras de Negócio

## 👥 Suporte

Para dúvidas ou problemas:
1. Verificar documentação técnica
2. Revisar logs de auditoria
3. Consultar exemplos nos templates
4. Contatar equipe de desenvolvimento

## 📄 Licença

Propriedade da Empresa de Serviços Digitais
Desenvolvido para: Loja de Roupas "Elegância Premium"

---

**Versão:** 1.0  
**Data:** Novembro 2025  
**Status:** Produção