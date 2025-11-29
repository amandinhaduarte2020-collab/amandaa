"""
APLICAÇÃO FLASK - SISTEMA ELEGÂNCIA PREMIUM
Sistema de Gerenciamento de Clientes, Produtos e Vendas
Versão 1.0 - Novembro 2025
"""

import os
import json
import hashlib
import hmac
from datetime import datetime, timedelta
from functools import wraps
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from flask_mysqldb import MySQL
import MySQLdb.cursors
from werkzeug.security import generate_password_hash, check_password_hash

# ============================================================
# CONFIGURAÇÃO DA APLICAÇÃO
# ============================================================

app = Flask(__name__)
app.secret_key = 'sua_chave_secreta_super_segura_aqui_2025'

# Configuração do MySQL
app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = ''  # Alterar conforme ambiente
app.config['MYSQL_DB'] = 'elegancia_premium'
app.config['MYSQL_CURSORCLASS'] = 'DictCursor'

mysql = MySQL(app)

# ============================================================
# DECORADORES DE AUTENTICAÇÃO E PERMISSÃO
# ============================================================

def login_required(f):
    """Verifica se usuário está autenticado"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logado' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def permissao_requerida(permissoes_permitidas):
    """Verifica se usuário tem permissão para acessar recurso"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'logado' not in session:
                return redirect(url_for('login'))
            
            if session['permissao'] not in permissoes_permitidas:
                return jsonify({'erro': 'Acesso negado'}), 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def registrar_auditoria(id_usuario, operacao, tabela, valor_anterior=None, valor_novo=None, ip=''):
    """Registra operação em auditoria"""
    try:
        cursor = mysql.connection.cursor()
        cursor.execute("""
            INSERT INTO audit_log (id_usuario, operacao, tabela_afetada, valor_anterior, valor_novo, ip_origem)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (id_usuario, operacao, tabela, valor_anterior, valor_novo, ip))
        mysql.connection.commit()
        cursor.close()
    except Exception as e:
        print(f"Erro ao registrar auditoria: {e}")

# ============================================================
# ROTAS DE AUTENTICAÇÃO
# ============================================================

@app.route('/')
def index():
    """Página inicial - redireciona para dashboard se logado"""
    if 'logado' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Autenticação de usuários"""
    if request.method == 'POST':
        email = request.form.get('email')
        senha = request.form.get('senha')
        
        cursor = mysql.connection.cursor()
        cursor.execute('SELECT * FROM usuarios WHERE email = %s AND ativo = TRUE', (email,))
        usuario = cursor.fetchone()
        cursor.close()
        
        if usuario and check_password_hash(usuario['senha'], senha):
            session['logado'] = True
            session['id_usuario'] = usuario['id_usuario']
            session['nome'] = usuario['nome']
            session['email'] = usuario['email']
            session['permissao'] = usuario['permissao']
            
            registrar_auditoria(usuario['id_usuario'], 'LOGIN', 'usuarios', None, 
                              json.dumps({'email': email}), request.remote_addr)
            
            return redirect(url_for('dashboard'))
        else:
            return render_template('login.html', erro='Email ou senha inválidos')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """Logout do usuário"""
    if 'logado' in session:
        registrar_auditoria(session['id_usuario'], 'LOGOUT', 'usuarios', None, None, request.remote_addr)
    session.clear()
    return redirect(url_for('login'))

# ============================================================
# ROTAS DO PAINEL ADMINISTRATIVO
# ============================================================

@app.route('/dashboard')
@login_required
def dashboard():
    """Dashboard principal com estatísticas"""
    cursor = mysql.connection.cursor()
    
    # Estatísticas gerais
    cursor.execute('SELECT COUNT(*) as total FROM vendas WHERE status = "CONCLUIDA"')
    total_vendas = cursor.fetchone()['total']
    
    cursor.execute('SELECT SUM(valor_total) as total FROM vendas WHERE status = "CONCLUIDA"')
    resultado = cursor.fetchone()
    valor_vendas = resultado['total'] if resultado['total'] else 0
    
    cursor.execute('SELECT COUNT(*) as total FROM clientes WHERE status = "ATIVO"')
    total_clientes = cursor.fetchone()['total']
    
    cursor.execute('SELECT COUNT(*) as total FROM produto_variacao WHERE quantidade_estoque <= quantidade_minima')
    produtos_baixos = cursor.fetchone()['total']
    
    cursor.close()
    
    return render_template('dashboard.html', 
                         total_vendas=total_vendas,
                         valor_vendas=f"{valor_vendas:.2f}",
                         total_clientes=total_clientes,
                         produtos_baixos=produtos_baixos)

# ============================================================
# ROTAS DE CLIENTES
# ============================================================

@app.route('/api/clientes', methods=['GET', 'POST'])
@login_required
def clientes():
    """Lista ou cria clientes"""
    if request.method == 'GET':
        cursor = mysql.connection.cursor()
        cursor.execute('SELECT * FROM clientes WHERE status = "ATIVO" ORDER BY nome')
        clientes_list = cursor.fetchall()
        cursor.close()
        return jsonify(clientes_list)
    
    elif request.method == 'POST':
        dados = request.get_json()
        cursor = mysql.connection.cursor()
        
        try:
            cursor.execute("""
                INSERT INTO clientes (nome, cpf, email, telefone, endereco, preferencias)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (dados['nome'], dados['cpf'], dados.get('email', ''), 
                  dados.get('telefone', ''), dados.get('endereco', ''), 
                  json.dumps(dados.get('preferencias', {}))))
            
            mysql.connection.commit()
            id_cliente = cursor.lastrowid
            cursor.close()
            
            registrar_auditoria(session['id_usuario'], 'INSERT', 'clientes', None,
                              json.dumps(dados), request.remote_addr)
            
            return jsonify({'sucesso': True, 'id': id_cliente}), 201
        except MySQLdb.IntegrityError as e:
            cursor.close()
            return jsonify({'erro': 'CPF já cadastrado'}), 409
        except Exception as e:
            cursor.close()
            return jsonify({'erro': str(e)}), 500

@app.route('/api/clientes/<int:id_cliente>', methods=['GET', 'PUT', 'DELETE'])
@login_required
def cliente_detalhes(id_cliente):
    """Detalha, atualiza ou deleta cliente"""
    cursor = mysql.connection.cursor()
    
    if request.method == 'GET':
        cursor.execute('SELECT * FROM clientes WHERE id_cliente = %s', (id_cliente,))
        cliente = cursor.fetchone()
        cursor.close()
        
        if cliente:
            return jsonify(cliente)
        return jsonify({'erro': 'Cliente não encontrado'}), 404
    
    elif request.method == 'PUT':
        dados = request.get_json()
        cursor.execute('SELECT * FROM clientes WHERE id_cliente = %s', (id_cliente,))
        cliente_antigo = cursor.fetchone()
        
        try:
            cursor.execute("""
                UPDATE clientes SET nome=%s, email=%s, telefone=%s, endereco=%s, 
                preferencias=%s WHERE id_cliente=%s
            """, (dados.get('nome', cliente_antigo['nome']),
                  dados.get('email', cliente_antigo['email']),
                  dados.get('telefone', cliente_antigo['telefone']),
                  dados.get('endereco', cliente_antigo['endereco']),
                  json.dumps(dados.get('preferencias', {})),
                  id_cliente))
            
            mysql.connection.commit()
            cursor.close()
            
            registrar_auditoria(session['id_usuario'], 'UPDATE', 'clientes',
                              json.dumps(cliente_antigo), json.dumps(dados), request.remote_addr)
            
            return jsonify({'sucesso': True})
        except Exception as e:
            cursor.close()
            return jsonify({'erro': str(e)}), 500
    
    elif request.method == 'DELETE':
        if session['permissao'] != 'GERENTE':
            return jsonify({'erro': 'Apenas gerentes podem deletar'}), 403
        
        try:
            cursor.execute('UPDATE clientes SET status="INATIVO" WHERE id_cliente=%s', (id_cliente,))
            mysql.connection.commit()
            cursor.close()
            
            registrar_auditoria(session['id_usuario'], 'DELETE', 'clientes', None,
                              json.dumps({'id_cliente': id_cliente}), request.remote_addr)
            
            return jsonify({'sucesso': True})
        except Exception as e:
            cursor.close()
            return jsonify({'erro': str(e)}), 500

# ============================================================
# ROTAS DE PRODUTOS
# ============================================================

@app.route('/api/produtos', methods=['GET', 'POST'])
@login_required
def produtos():
    """Lista ou cria produtos"""
    if request.method == 'GET':
        cursor = mysql.connection.cursor()
        cursor.execute("""
            SELECT p.*, c.nome as colecao_nome 
            FROM produtos p
            INNER JOIN colecoes c ON p.id_colecao = c.id_colecao
            WHERE p.ativo = TRUE
            ORDER BY p.nome
        """)
        produtos_list = cursor.fetchall()
        cursor.close()
        return jsonify(produtos_list)
    
    elif request.method == 'POST':
        if session['permissao'] != 'GERENTE':
            return jsonify({'erro': 'Apenas gerentes podem criar produtos'}), 403
        
        dados = request.get_json()
        cursor = mysql.connection.cursor()
        
        try:
            cursor.execute("""
                INSERT INTO produtos (id_colecao, nome, descricao, preco_base)
                VALUES (%s, %s, %s, %s)
            """, (dados['id_colecao'], dados['nome'], dados.get('descricao', ''), dados['preco_base']))
            
            mysql.connection.commit()
            id_produto = cursor.lastrowid
            cursor.close()
            
            registrar_auditoria(session['id_usuario'], 'INSERT', 'produtos', None,
                              json.dumps(dados), request.remote_addr)
            
            return jsonify({'sucesso': True, 'id': id_produto}), 201
        except Exception as e:
            cursor.close()
            return jsonify({'erro': str(e)}), 500

@app.route('/api/produtos/<int:id_produto>/variacoes')
@login_required
def produto_variacoes(id_produto):
    """Lista variações de um produto"""
    cursor = mysql.connection.cursor()
    cursor.execute("""
        SELECT pv.*, p.nome as produto_nome, c.nome as cor_nome, t.valor as tamanho_valor, f.nome as fornecedor_nome
        FROM produto_variacao pv
        INNER JOIN produtos p ON pv.id_produto = p.id_produto
        INNER JOIN cores c ON pv.id_cor = c.id_cor
        INNER JOIN tamanhos t ON pv.id_tamanho = t.id_tamanho
        LEFT JOIN fornecedores f ON pv.id_fornecedor = f.id_fornecedor
        WHERE pv.id_produto = %s
        ORDER BY c.nome, t.ordem
    """, (id_produto,))
    variacoes = cursor.fetchall()
    cursor.close()
    return jsonify(variacoes)

# ============================================================
# ROTAS DE ESTOQUE
# ============================================================

@app.route('/api/estoque', methods=['GET'])
@login_required
def estoque():
    """Consulta estoque com filtros"""
    filtro_produto = request.args.get('produto', '')
    filtro_colecao = request.args.get('colecao', '')
    
    cursor = mysql.connection.cursor()
    
    query = """
        SELECT pv.id_variacao, pv.sku, p.nome as produto_nome, c.nome as colecao_nome,
               cor.nome as cor_nome, t.valor as tamanho_valor, pv.quantidade_estoque,
               pv.quantidade_minima, f.nome as fornecedor_nome
        FROM produto_variacao pv
        INNER JOIN produtos p ON pv.id_produto = p.id_produto
        INNER JOIN colecoes c ON p.id_colecao = c.id_colecao
        INNER JOIN cores cor ON pv.id_cor = cor.id_cor
        INNER JOIN tamanhos t ON pv.id_tamanho = t.id_tamanho
        LEFT JOIN fornecedores f ON pv.id_fornecedor = f.id_fornecedor
        WHERE p.ativo = TRUE
    """
    
    params = []
    if filtro_produto:
        query += " AND p.nome LIKE %s"
        params.append(f"%{filtro_produto}%")
    
    if filtro_colecao:
        query += " AND c.id_colecao = %s"
        params.append(filtro_colecao)
    
    query += " ORDER BY p.nome, cor.nome, t.ordem"
    
    cursor.execute(query, params)
    estoque_list = cursor.fetchall()
    cursor.close()
    return jsonify(estoque_list)

@app.route('/api/estoque/<int:id_variacao>', methods=['PUT'])
@login_required
@permissao_requerida(['ESTOQUISTA', 'GERENTE'])
def atualizar_estoque(id_variacao):
    """Atualiza quantidade em estoque"""
    dados = request.get_json()
    cursor = mysql.connection.cursor()
    
    cursor.execute('SELECT * FROM produto_variacao WHERE id_variacao = %s', (id_variacao,))
    variacao_antiga = cursor.fetchone()
    
    if not variacao_antiga:
        cursor.close()
        return jsonify({'erro': 'Variação não encontrada'}), 404
    
    try:
        nova_quantidade = dados.get('quantidade_estoque')
        motivo = dados.get('motivo', 'Ajuste manual')
        
        cursor.execute("""
            UPDATE produto_variacao 
            SET quantidade_estoque = %s
            WHERE id_variacao = %s
        """, (nova_quantidade, id_variacao))
        
        mysql.connection.commit()
        cursor.close()
        
        registrar_auditoria(session['id_usuario'], 'UPDATE', 'produto_variacao',
                          json.dumps({'quantidade_anterior': variacao_antiga['quantidade_estoque']}),
                          json.dumps({'quantidade_nova': nova_quantidade, 'motivo': motivo}),
                          request.remote_addr)
        
        return jsonify({'sucesso': True})
    except Exception as e:
        cursor.close()
        return jsonify({'erro': str(e)}), 500

@app.route('/api/estoque/baixo')
@login_required
def estoque_baixo():
    """Lista produtos com estoque baixo"""
    cursor = mysql.connection.cursor()
    cursor.execute('SELECT * FROM v_estoque_baixo')
    estoque_baixo = cursor.fetchall()
    cursor.close()
    return jsonify(estoque_baixo)

# ============================================================
# ROTAS DE VENDAS
# ============================================================

@app.route('/api/vendas', methods=['GET', 'POST'])
@login_required
def vendas():
    """Lista ou cria vendas"""
    if request.method == 'GET':
        cursor = mysql.connection.cursor()
        cursor.execute('SELECT * FROM v_vendas_detalhadas ORDER BY data_venda DESC LIMIT 100')
        vendas_list = cursor.fetchall()
        cursor.close()
        return jsonify(vendas_list)
    
    elif request.method == 'POST':
        if session['permissao'] not in ['VENDEDOR', 'GERENTE']:
            return jsonify({'erro': 'Apenas vendedores podem registrar vendas'}), 403
        
        dados = request.get_json()
        cursor = mysql.connection.cursor()
        
        try:
            # Validar cliente
            cursor.execute('SELECT id_cliente FROM clientes WHERE id_cliente = %s AND status = "ATIVO"', 
                          (dados['id_cliente'],))
            if not cursor.fetchone():
                cursor.close()
                return jsonify({'erro': 'Cliente não encontrado'}), 404
            
            # Iniciar transação
            cursor.execute('START TRANSACTION')
            
            # Criar venda
            valor_subtotal = sum(item['quantidade'] * item['preco_unitario'] for item in dados['itens'])
            valor_desconto = dados.get('valor_desconto', 0)
            valor_total = valor_subtotal - valor_desconto
            
            cursor.execute("""
                INSERT INTO vendas (id_cliente, id_usuario, valor_subtotal, valor_desconto, valor_total)
                VALUES (%s, %s, %s, %s, %s)
            """, (dados['id_cliente'], session['id_usuario'], valor_subtotal, valor_desconto, valor_total))
            
            id_venda = cursor.lastrowid
            
            # Inserir itens e atualizar estoque
            for item in dados['itens']:
                # Validar estoque
                cursor.execute("""
                    SELECT quantidade_estoque FROM produto_variacao WHERE id_variacao = %s
                """, (item['id_variacao'],))
                resultado = cursor.fetchone()
                
                if not resultado or resultado['quantidade_estoque'] < item['quantidade']:
                    cursor.execute('ROLLBACK')
                    cursor.close()
                    return jsonify({'erro': f'Estoque insuficiente para item {item["id_variacao"]}'}), 409
                
                # Inserir item
                cursor.execute("""
                    INSERT INTO item_venda (id_venda, id_variacao, quantidade, preco_unitario, subtotal)
                    VALUES (%s, %s, %s, %s, %s)
                """, (id_venda, item['id_variacao'], item['quantidade'], 
                      item['preco_unitario'], item['quantidade'] * item['preco_unitario']))
                
                # Atualizar estoque
                cursor.execute("""
                    UPDATE produto_variacao 
                    SET quantidade_estoque = quantidade_estoque - %s
                    WHERE id_variacao = %s
                """, (item['quantidade'], item['id_variacao']))
            
            # Atualizar data última compra do cliente
            cursor.execute("""
                UPDATE clientes SET data_ultima_compra = NOW() WHERE id_cliente = %s
            """, (dados['id_cliente'],))
            
            cursor.execute('COMMIT')
            mysql.connection.commit()
            cursor.close()
            
            registrar_auditoria(session['id_usuario'], 'INSERT', 'vendas', None,
                              json.dumps({'id_venda': id_venda, 'id_cliente': dados['id_cliente'],
                                        'valor_total': valor_total}), request.remote_addr)
            
            return jsonify({'sucesso': True, 'id_venda': id_venda}), 201
        except Exception as e:
            cursor.execute('ROLLBACK')
            cursor.close()
            return jsonify({'erro': str(e)}), 500

@app.route('/api/vendas/<int:id_venda>')
@login_required
def venda_detalhes(id_venda):
    """Detalhes de uma venda"""
    cursor = mysql.connection.cursor()
    cursor.execute('SELECT * FROM v_vendas_detalhadas WHERE id_venda = %s', (id_venda,))
    itens = cursor.fetchall()
    cursor.close()
    
    if not itens:
        return jsonify({'erro': 'Venda não encontrada'}), 404
    
    return jsonify(itens)

# ============================================================
# ROTAS DE DEVOLUÇÕES
# ============================================================

@app.route('/api/devolucoes', methods=['POST'])
@login_required
@permissao_requerida(['VENDEDOR', 'GERENTE'])
def criar_devolucao():
    """Registra uma devolução"""
    dados = request.get_json()
    cursor = mysql.connection.cursor()
    
    try:
        # Validar venda
        cursor.execute('SELECT * FROM vendas WHERE id_venda = %s', (dados['id_venda'],))
        venda = cursor.fetchone()
        
        if not venda:
            cursor.close()
            return jsonify({'erro': 'Venda não encontrada'}), 404
        
        # Iniciar transação
        cursor.execute('START TRANSACTION')
        
        # Criar devolução
        cursor.execute("""
            INSERT INTO devolucoes (id_venda, id_usuario, motivo, valor_reembolso)
            VALUES (%s, %s, %s, %s)
        """, (dados['id_venda'], session['id_usuario'], dados['motivo'], venda['valor_total']))
        
        id_devolucao = cursor.lastrowid
        
        # Repor estoque
        cursor.execute("""
            SELECT id_variacao, quantidade FROM item_venda WHERE id_venda = %s
        """, (dados['id_venda'],))
        
        itens = cursor.fetchall()
        for item in itens:
            cursor.execute("""
                UPDATE produto_variacao 
                SET quantidade_estoque = quantidade_estoque + %s
                WHERE id_variacao = %s
            """, (item['quantidade'], item['id_variacao']))
        
        # Atualizar status da venda
        cursor.execute("""
            UPDATE vendas SET status = 'DEVOLVIDA' WHERE id_venda = %s
        """, (dados['id_venda'],))
        
        cursor.execute('COMMIT')
        mysql.connection.commit()
        cursor.close()
        
        registrar_auditoria(session['id_usuario'], 'INSERT', 'devolucoes', None,
                          json.dumps({'id_devolucao': id_devolucao, 'id_venda': dados['id_venda']}),
                          request.remote_addr)
        
        return jsonify({'sucesso': True, 'id_devolucao': id_devolucao}), 201
    except Exception as e:
        cursor.execute('ROLLBACK')
        cursor.close()
        return jsonify({'erro': str(e)}), 500

# ============================================================
# ROTAS DE RELATÓRIOS
# ============================================================

@app.route('/api/relatorios/vendas-por-periodo')
@login_required
@permissao_requerida(['GERENTE'])
def relatorio_vendas_periodo():
    """Relatório de vendas por período"""
    data_inicio = request.args.get('data_inicio')
    data_fim = request.args.get('data_fim')
    
    cursor = mysql.connection.cursor()
    cursor.execute("""
        SELECT DATE(v.data_venda) as data, COUNT(*) as total_vendas, SUM(v.valor_total) as valor_total
        FROM vendas v
        WHERE DATE(v.data_venda) BETWEEN %s AND %s AND v.status = 'CONCLUIDA'
        GROUP BY DATE(v.data_venda)
        ORDER BY DATE(v.data_venda)
    """, (data_inicio, data_fim))
    
    resultado = cursor.fetchall()
    cursor.close()
    return jsonify(resultado)

@app.route('/api/relatorios/vendas-por-vendedor')
@login_required
@permissao_requerida(['GERENTE'])
def relatorio_vendas_vendedor():
    """Relatório de vendas por vendedor"""
    data_inicio = request.args.get('data_inicio', (datetime.now() - timedelta(days=30)).date())
    data_fim = request.args.get('data_fim', datetime.now().date())
    
    cursor = mysql.connection.cursor()
    cursor.execute("""
        SELECT u.nome, COUNT(v.id_venda) as total_vendas, SUM(v.valor_total) as valor_total
        FROM vendas v
        INNER JOIN usuarios u ON v.id_usuario = u.id_usuario
        WHERE DATE(v.data_venda) BETWEEN %s AND %s AND v.status = 'CONCLUIDA'
        GROUP BY v.id_usuario
        ORDER BY valor_total DESC
    """, (data_inicio, data_fim))
    
    resultado = cursor.fetchall()
    cursor.close()
    return jsonify(resultado)

@app.route('/api/relatorios/vendas-por-colecao')
@login_required
@permissao_requerida(['GERENTE'])
def relatorio_vendas_colecao():
    """Relatório de vendas por coleção"""
    data_inicio = request.args.get('data_inicio', (datetime.now() - timedelta(days=30)).date())
    data_fim = request.args.get('data_fim', datetime.now().date())
    
    cursor = mysql.connection.cursor()
    cursor.execute("""
        SELECT c.nome, COUNT(DISTINCT v.id_venda) as total_vendas, SUM(iv.subtotal) as valor_total, SUM(iv.quantidade) as quantidade
        FROM vendas v
        INNER JOIN item_venda iv ON v.id_venda = iv.id_venda
        INNER JOIN produto_variacao pv ON iv.id_variacao = pv.id_variacao
        INNER JOIN produtos p ON pv.id_produto = p.id_produto
        INNER JOIN colecoes c ON p.id_colecao = c.id_colecao
        WHERE DATE(v.data_venda) BETWEEN %s AND %s AND v.status = 'CONCLUIDA'
        GROUP BY c.id_colecao
        ORDER BY valor_total DESC
    """, (data_inicio, data_fim))
    
    resultado = cursor.fetchall()
    cursor.close()
    return jsonify(resultado)

@app.route('/api/relatorios/auditoria')
@login_required
@permissao_requerida(['GERENTE'])
def relatorio_auditoria():
    """Relatório de auditoria"""
    data_inicio = request.args.get('data_inicio', (datetime.now() - timedelta(days=7)).date())
    data_fim = request.args.get('data_fim', datetime.now().date())
    
    cursor = mysql.connection.cursor()
    cursor.execute("""
        SELECT u.nome, a.operacao, a.tabela_afetada, a.data_hora, a.ip_origem
        FROM audit_log a
        LEFT JOIN usuarios u ON a.id_usuario = u.id_usuario
        WHERE DATE(a.data_hora) BETWEEN %s AND %s
        ORDER BY a.data_hora DESC
        LIMIT 1000
    """, (data_inicio, data_fim))
    
    resultado = cursor.fetchall()
    cursor.close()
    return jsonify(resultado)

# ============================================================
# TRATAMENTO DE ERROS
# ============================================================

@app.errorhandler(404)
def nao_encontrado(error):
    return jsonify({'erro': 'Recurso não encontrado'}), 404

@app.errorhandler(500)
def erro_interno(error):
    return jsonify({'erro': 'Erro interno do servidor'}), 500

# ============================================================
# INICIALIZAÇÃO
# ============================================================

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)