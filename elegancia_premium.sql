-- ============================================================
-- SISTEMA DE GERENCIAMENTO "ELEGÂNCIA PREMIUM"
-- Banco de Dados MySQL - 3FN Normalizado
-- ============================================================
-- Data: Novembro 2025
-- Versão: 1.0
-- ============================================================

-- Criar banco de dados
DROP DATABASE IF EXISTS elegancia_premium;
CREATE DATABASE elegancia_premium 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

USE elegancia_premium;

-- ============================================================
-- 1. TABELA: USUARIOS (Controle de Acesso)
-- ============================================================
-- Dependência: Nenhuma (tabela raiz)
-- Normalização: 3FN ✓ (apenas dados de autenticação)
-- Justificativa: Tabela de usuários do sistema com permissões

CREATE TABLE usuarios (
  id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  senha VARCHAR(255) NOT NULL COMMENT 'Hash bcrypt da senha',
  permissao ENUM('VENDEDOR', 'ESTOQUISTA', 'GERENTE') NOT NULL DEFAULT 'VENDEDOR',
  ativo BOOLEAN DEFAULT TRUE,
  data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
  data_ultima_atualizacao DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_email (email),
  INDEX idx_permissao (permissao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Usuários do sistema com controle de permissões';

-- ============================================================
-- 2. TABELA: CLIENTES (Cadastro de Clientes)
-- ============================================================
-- Dependência: Nenhuma (tabela raiz)
-- Normalização: 3FN ✓ (CPF normalizado, dados atomizados)
-- Justificativa: Dados dos clientes da loja

CREATE TABLE clientes (
  id_cliente INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(150) NOT NULL,
  cpf VARCHAR(11) UNIQUE NOT NULL COMMENT 'CPF sem caracteres especiais',
  email VARCHAR(100),
  telefone VARCHAR(11),
  endereco TEXT,
  preferencias JSON COMMENT 'Preferências de compra em JSON',
  data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
  data_ultima_compra DATETIME,
  status ENUM('ATIVO', 'INATIVO') DEFAULT 'ATIVO',
  
  INDEX idx_cpf (cpf),
  INDEX idx_email (email),
  INDEX idx_nome (nome),
  FULLTEXT INDEX ft_nome (nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Cadastro de clientes com rastreamento de preferências';

-- ============================================================
-- 3. TABELA: COLECOES (Agrupamento de Produtos)
-- ============================================================
-- Dependência: Nenhuma (tabela raiz)
-- Normalização: 3FN ✓ (dados de coleção independentes)
-- Justificativa: Define períodos e temas de coleções

CREATE TABLE colecoes (
  id_colecao INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NOT NULL UNIQUE,
  descricao TEXT,
  data_inicio DATE NOT NULL,
  data_fim DATE NOT NULL,
  ativa BOOLEAN DEFAULT TRUE,
  data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_ativa (ativa),
  INDEX idx_datas (data_inicio, data_fim)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Coleções de produtos com vigência temporal';

-- ============================================================
-- 4. TABELA: FORNECEDORES (Cadastro de Fornecedores)
-- ============================================================
-- Dependência: Nenhuma (tabela raiz)
-- Normalização: 3FN ✓ (dados de fornecedor atomizados)
-- Justificativa: Cadastro de fornecedores para requisição de estoque

CREATE TABLE fornecedores (
  id_fornecedor INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(150) NOT NULL,
  cnpj VARCHAR(14) UNIQUE NOT NULL,
  email VARCHAR(100),
  telefone VARCHAR(11),
  endereco TEXT,
  contato_principal VARCHAR(100),
  data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
  ativo BOOLEAN DEFAULT TRUE,
  
  INDEX idx_cnpj (cnpj),
  INDEX idx_ativo (ativo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Cadastro de fornecedores de produtos';

-- ============================================================
-- 5. TABELA: PRODUTOS (Catálogo Principal)
-- ============================================================
-- Dependência: colecoes (1:N)
-- Normalização: 3FN ✓ (chave estrangeira para coleção)
-- Justificativa: Produtos base sem variações (cores/tamanhos)

CREATE TABLE produtos (
  id_produto INT AUTO_INCREMENT PRIMARY KEY,
  id_colecao INT NOT NULL,
  nome VARCHAR(150) NOT NULL,
  descricao TEXT,
  preco_base DECIMAL(10, 2) NOT NULL,
  ativo BOOLEAN DEFAULT TRUE,
  data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
  data_ultima_atualizacao DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (id_colecao) REFERENCES colecoes(id_colecao) ON DELETE RESTRICT,
  INDEX idx_colecao (id_colecao),
  INDEX idx_nome (nome),
  INDEX idx_ativo (ativo),
  FULLTEXT INDEX ft_nome_descricao (nome, descricao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catálogo de produtos associados a coleções';

-- ============================================================
-- 6. TABELA: CORES (Paleta de Cores)
-- ============================================================
-- Dependência: Nenhuma (tabela raiz)
-- Normalização: 3FN ✓ (dados atomizados de cor)
-- Justificativa: Permite reutilização de cores em múltiplos produtos

CREATE TABLE cores (
  id_cor INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(50) NOT NULL UNIQUE,
  hex_code VARCHAR(7) COMMENT 'Código hexadecimal da cor',
  data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_nome (nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Paleta de cores disponíveis para produtos';

-- ============================================================
-- 7. TABELA: TAMANHOS (Grade de Tamanhos)
-- ============================================================
-- Dependência: Nenhuma (tabela raiz)
-- Normalização: 3FN ✓ (dados independentes)
-- Justificativa: Permite reutilização de tamanhos em múltiplos produtos

CREATE TABLE tamanhos (
  id_tamanho INT AUTO_INCREMENT PRIMARY KEY,
  valor VARCHAR(10) NOT NULL UNIQUE COMMENT 'P, M, G, GG, 34, 36, etc',
  ordem INT COMMENT 'Ordem para exibição',
  descricao VARCHAR(100),
  
  INDEX idx_ordem (ordem)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Grade de tamanhos disponíveis';

-- ============================================================
-- 8. TABELA: PRODUTO_VARIACAO (SKU com Estoque)
-- ============================================================
-- Dependência: produtos (1:N), cores (1:N), tamanhos (1:N)
-- Normalização: 3FN ✓ (todas as dependências resolvidas por FK)
-- Justificativa: Combinação produto+cor+tamanho = SKU com controle de estoque

CREATE TABLE produto_variacao (
  id_variacao INT AUTO_INCREMENT PRIMARY KEY,
  id_produto INT NOT NULL,
  id_cor INT NOT NULL,
  id_tamanho INT NOT NULL,
  sku VARCHAR(50) UNIQUE NOT NULL COMMENT 'Identificador único: PROD-001-ROSA-M',
  quantidade_estoque INT NOT NULL DEFAULT 0,
  quantidade_minima INT DEFAULT 5,
  id_fornecedor INT,
  data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
  data_ultima_atualizacao DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (id_produto) REFERENCES produtos(id_produto) ON DELETE CASCADE,
  FOREIGN KEY (id_cor) REFERENCES cores(id_cor) ON DELETE RESTRICT,
  FOREIGN KEY (id_tamanho) REFERENCES tamanhos(id_tamanho) ON DELETE RESTRICT,
  FOREIGN KEY (id_fornecedor) REFERENCES fornecedores(id_fornecedor) ON DELETE SET NULL,
  
  UNIQUE KEY uk_produto_cor_tamanho (id_produto, id_cor, id_tamanho),
  INDEX idx_sku (sku),
  INDEX idx_quantidade_estoque (quantidade_estoque),
  INDEX idx_fornecedor (id_fornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Variações de produtos (SKU) com controle de estoque';

-- ============================================================
-- 9. TABELA: PROMOCOES (Campanhas Promocionais)
-- ============================================================
-- Dependência: Nenhuma (tabela raiz)
-- Normalização: 3FN ✓ (dados de promoção independentes)
-- Justificativa: Define promoções com vigência temporal

CREATE TABLE promocoes (
  id_promocao INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NOT NULL UNIQUE,
  descricao TEXT,
  percentual_desconto DECIMAL(5, 2) NOT NULL COMMENT 'Percentual de desconto (0-100)',
  data_inicio DATETIME NOT NULL,
  data_fim DATETIME NOT NULL,
  ativa BOOLEAN DEFAULT TRUE,
  criada_por INT,
  data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (criada_por) REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
  INDEX idx_data_inicio (data_inicio),
  INDEX idx_data_fim (data_fim),
  INDEX idx_ativa (ativa)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Promoções com vigência temporal';

-- ============================================================
-- 10. TABELA: PRODUTO_PROMOCAO (Associação N:N)
-- ============================================================
-- Dependência: promocoes (1:N), produtos (1:N)
-- Normalização: 3FN ✓ (tabela de associação)
-- Justificativa: Resolve relacionamento N:N entre produtos e promoções

CREATE TABLE produto_promocao (
  id_assoc INT AUTO_INCREMENT PRIMARY KEY,
  id_promocao INT NOT NULL,
  id_produto INT NOT NULL,
  data_associacao DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (id_promocao) REFERENCES promocoes(id_promocao) ON DELETE CASCADE,
  FOREIGN KEY (id_produto) REFERENCES produtos(id_produto) ON DELETE CASCADE,
  UNIQUE KEY uk_promocao_produto (id_promocao, id_produto),
  INDEX idx_promocao (id_promocao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Associação entre promoções e produtos (N:N)';

-- ============================================================
-- 11. TABELA: VENDAS (Transações de Venda)
-- ============================================================
-- Dependência: clientes (1:N), usuarios (1:N)
-- Normalização: 3FN ✓ (dados agregados apenas)
-- Justificativa: Cabeçalho de venda com totalizações

CREATE TABLE vendas (
  id_venda INT AUTO_INCREMENT PRIMARY KEY,
  id_cliente INT NOT NULL,
  id_usuario INT NOT NULL COMMENT 'Vendedor que registrou',
  data_venda DATETIME DEFAULT CURRENT_TIMESTAMP,
  valor_subtotal DECIMAL(10, 2) NOT NULL,
  valor_desconto DECIMAL(10, 2) DEFAULT 0,
  valor_total DECIMAL(10, 2) NOT NULL,
  status ENUM('CONCLUIDA', 'CANCELADA', 'DEVOLVIDA') DEFAULT 'CONCLUIDA',
  observacoes TEXT,
  
  FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE RESTRICT,
  FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE RESTRICT,
  INDEX idx_cliente (id_cliente),
  INDEX idx_usuario (id_usuario),
  INDEX idx_data_venda (data_venda),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Cabeçalho de transações de venda';

-- ============================================================
-- 12. TABELA: ITEM_VENDA (Itens por Venda)
-- ============================================================
-- Dependência: vendas (1:N), produto_variacao (1:N)
-- Normalização: 3FN ✓ (chaves estrangeiras resolvem dependências)
-- Justificativa: Detalhamento de cada item vendido

CREATE TABLE item_venda (
  id_item INT AUTO_INCREMENT PRIMARY KEY,
  id_venda INT NOT NULL,
  id_variacao INT NOT NULL,
  quantidade INT NOT NULL,
  preco_unitario DECIMAL(10, 2) NOT NULL,
  desconto_percentual DECIMAL(5, 2) DEFAULT 0,
  subtotal DECIMAL(10, 2) NOT NULL,
  
  FOREIGN KEY (id_venda) REFERENCES vendas(id_venda) ON DELETE CASCADE,
  FOREIGN KEY (id_variacao) REFERENCES produto_variacao(id_variacao) ON DELETE RESTRICT,
  INDEX idx_venda (id_venda),
  INDEX idx_variacao (id_variacao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Detalhamento de itens por venda';

-- ============================================================
-- 13. TABELA: DEVOLUCOES (Registro de Devoluções)
-- ============================================================
-- Dependência: vendas (1:1), usuarios (1:N)
-- Normalização: 3FN ✓ (dados atomizados)
-- Justificativa: Registra devoluções e reembolsos

CREATE TABLE devolucoes (
  id_devolucao INT AUTO_INCREMENT PRIMARY KEY,
  id_venda INT NOT NULL,
  id_usuario INT NOT NULL COMMENT 'Usuário que processou',
  motivo TEXT NOT NULL,
  data_devolucao DATETIME DEFAULT CURRENT_TIMESTAMP,
  valor_reembolso DECIMAL(10, 2) NOT NULL,
  status ENUM('PENDENTE', 'PROCESSADA', 'REEMBOLSADA') DEFAULT 'PENDENTE',
  
  FOREIGN KEY (id_venda) REFERENCES vendas(id_venda) ON DELETE RESTRICT,
  FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE RESTRICT,
  UNIQUE KEY uk_venda_devolucao (id_venda),
  INDEX idx_data (data_devolucao),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro de devoluções de produtos';

-- ============================================================
-- 14. TABELA: AUDIT_LOG (Auditoria Completa)
-- ============================================================
-- Dependência: usuarios (1:N)
-- Normalização: 3FN ✓ (dados de log independentes)
-- Justificativa: Rastreabilidade de todas as operações

CREATE TABLE audit_log (
  id_log INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT,
  operacao VARCHAR(50) NOT NULL COMMENT 'INSERT, UPDATE, DELETE, LOGIN',
  tabela_afetada VARCHAR(50),
  valor_anterior LONGTEXT COMMENT 'JSON com valor anterior',
  valor_novo LONGTEXT COMMENT 'JSON com valor novo',
  data_hora DATETIME DEFAULT CURRENT_TIMESTAMP,
  ip_origem VARCHAR(45),
  user_agent VARCHAR(255),
  
  FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
  INDEX idx_data_hora (data_hora),
  INDEX idx_usuario (id_usuario),
  INDEX idx_operacao (operacao),
  INDEX idx_tabela (tabela_afetada)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Log de auditoria de todas as operações do sistema';

-- ============================================================
-- ÍNDICES ADICIONAIS PARA PERFORMANCE
-- ============================================================

-- Índices para consultas rápidas de disponibilidade
CREATE INDEX idx_pv_estoque ON produto_variacao(id_produto, quantidade_estoque);

-- Índices para relatórios
CREATE INDEX idx_vendas_data_usuario ON vendas(data_venda, id_usuario);
CREATE INDEX idx_vendas_data_cliente ON vendas(data_venda, id_cliente);
CREATE INDEX idx_item_venda_preco ON item_venda(id_variacao, preco_unitario);

-- Índices para consultas de estoque baixo
CREATE INDEX idx_estoque_baixo ON produto_variacao(quantidade_estoque, quantidade_minima);

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

-- 1. Procedure para registrar venda (transação atômica)
DELIMITER $$

CREATE PROCEDURE registrar_venda(
  IN p_id_cliente INT,
  IN p_id_usuario INT,
  IN p_valor_desconto DECIMAL(10,2),
  OUT p_id_venda_novo INT
)
BEGIN
  DECLARE v_valor_total DECIMAL(10,2) DEFAULT 0;
  
  -- Validar cliente e usuário existem
  IF NOT EXISTS (SELECT 1 FROM clientes WHERE id_cliente = p_id_cliente AND status = 'ATIVO') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente não encontrado ou inativo';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_usuario AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário não encontrado ou inativo';
  END IF;
  
  -- Criar venda
  INSERT INTO vendas (id_cliente, id_usuario, valor_subtotal, valor_desconto, valor_total)
  VALUES (p_id_cliente, p_id_usuario, 0, p_valor_desconto, 0);
  
  SET p_id_venda_novo = LAST_INSERT_ID();
  
  -- Registrar auditoria
  INSERT INTO audit_log (id_usuario, operacao, tabela_afetada, valor_novo, ip_origem)
  VALUES (p_id_usuario, 'INSERT', 'vendas', 
    CONCAT('{"id_venda":', p_id_venda_novo, ', "id_cliente":', p_id_cliente, '}'), 
    '0.0.0.0');
END$$

DELIMITER ;

-- 2. Procedure para validar estoque antes de venda
DELIMITER $$

CREATE PROCEDURE validar_estoque(
  IN p_id_variacao INT,
  IN p_quantidade INT,
  OUT p_resultado INT
)
BEGIN
  DECLARE v_estoque INT;
  
  SELECT quantidade_estoque INTO v_estoque
  FROM produto_variacao
  WHERE id_variacao = p_id_variacao;
  
  IF v_estoque IS NULL THEN
    SET p_resultado = 0; -- Variação não existe
  ELSEIF v_estoque < p_quantidade THEN
    SET p_resultado = 0; -- Estoque insuficiente
  ELSE
    SET p_resultado = 1; -- Estoque disponível
  END IF;
END$$

DELIMITER ;

-- 3. Procedure para calcular preço com promoção
DELIMITER $$

CREATE PROCEDURE calcular_preco_com_promocao(
  IN p_id_produto INT,
  IN p_preco_base DECIMAL(10,2),
  OUT p_preco_final DECIMAL(10,2)
)
BEGIN
  DECLARE v_desconto DECIMAL(5,2);
  
  SELECT COALESCE(MAX(p.percentual_desconto), 0) INTO v_desconto
  FROM promocoes p
  INNER JOIN produto_promocao pp ON p.id_promocao = pp.id_promocao
  WHERE pp.id_produto = p_id_produto
  AND p.data_inicio <= NOW()
  AND p.data_fim >= NOW()
  AND p.ativa = TRUE;
  
  SET p_preco_final = p_preco_base * (1 - (v_desconto / 100));
END$$

DELIMITER ;

-- ============================================================
-- DADOS INICIAIS PARA TESTES
-- ============================================================

-- Usuários
INSERT INTO usuarios (nome, email, senha, permissao) VALUES
('Maria da Silva', 'maria@elegancia.com', '$2b$12$abcd1234efgh5678ijkl9012mnopqrst', 'GERENTE'),
('Carlos Alberto', 'carlos@elegancia.com', '$2b$12$abcd1234efgh5678ijkl9012mnopqrst', 'VENDEDOR'),
('Patricia Oliveira', 'patricia@elegancia.com', '$2b$12$abcd1234efgh5678ijkl9012mnopqrst', 'ESTOQUISTA');

-- Coleções
INSERT INTO colecoes (nome, descricao, data_inicio, data_fim) VALUES
('Primavera 2025', 'Coleção primavera com estampas florais', '2025-09-01', '2025-11-30'),
('Verão 2026', 'Coleção verão com cores vibrantes', '2025-12-01', '2026-02-28'),
('Inverno 2025', 'Coleção inverno com tons quentes', '2025-06-01', '2025-08-31');

-- Fornecedores
INSERT INTO fornecedores (nome, cnpj, email, telefone) VALUES
('TextilBrasil', '12345678000190', 'vendas@textilbrasil.com', '1133334444'),
('ModaFashion', '98765432000111', 'contato@modafashion.com', '1144445555');

-- Cores
INSERT INTO cores (nome, hex_code) VALUES
('Rosa', '#FF69B4'),
('Azul', '#0000FF'),
('Preto', '#000000'),
('Branco', '#FFFFFF'),
('Verde', '#008000'),
('Amarelo', '#FFFF00');

-- Tamanhos
INSERT INTO tamanhos (valor, ordem) VALUES
('P', 1),
('M', 2),
('G', 3),
('GG', 4),
('XG', 5);

-- Produtos
INSERT INTO produtos (id_colecao, nome, descricao, preco_base) VALUES
(1, 'Camiseta Floral', 'Camiseta com estampa floral primavera', 89.90),
(1, 'Calça Jeans', 'Calça jeans premium primavera', 149.90),
(2, 'Bermuda Verão', 'Bermuda confortável para verão', 79.90);

-- Variações de produtos
INSERT INTO produto_variacao (id_produto, id_cor, id_tamanho, sku, quantidade_estoque, quantidade_minima, id_fornecedor) VALUES
(1, 1, 2, 'CAMISETA-FLORAL-ROSA-M', 10, 5, 1),
(1, 1, 3, 'CAMISETA-FLORAL-ROSA-G', 8, 5, 1),
(1, 2, 2, 'CAMISETA-FLORAL-AZUL-M', 15, 5, 1),
(2, 3, 2, 'CALCA-JEANS-PRETO-M', 12, 5, 2),
(3, 4, 3, 'BERMUDA-VERAO-BRANCO-G', 20, 5, 2);

-- Promoções
INSERT INTO promocoes (nome, descricao, percentual_desconto, data_inicio, data_fim, criada_por) VALUES
('VERÃO-10%', 'Promoção especial verão 10% desconto', 10, '2025-11-01 00:00:00', '2025-12-31 23:59:59', 1),
('BLACK-FRIDAY', 'Black Friday 50% desconto', 50, '2025-11-28 00:00:00', '2025-11-29 23:59:59', 1);

-- Clientes
INSERT INTO clientes (nome, cpf, email, telefone, endereco, preferencias) VALUES
('Mariana Ferreira', '12345678901', 'mariana@email.com', '11987654321', 'Rua das Flores, 100', '{"preferencias": ["Estampas Florais", "Tamanho M", "Cores Claras"]}'),
('João Silva', '98765432101', 'joao@email.com', '11987654322', 'Avenida Principal, 200', '{"preferencias": ["Jeans", "Tamanho G"]}');

-- ============================================================
-- VIEWS ÚTEIS
-- ============================================================

-- View: Produtos com Estoque Baixo
CREATE VIEW v_estoque_baixo AS
SELECT 
  p.nome AS produto,
  c.nome AS colecao,
  cor.nome AS cor,
  t.valor AS tamanho,
  pv.sku,
  pv.quantidade_estoque,
  pv.quantidade_minima,
  f.nome AS fornecedor
FROM produto_variacao pv
INNER JOIN produtos p ON pv.id_produto = p.id_produto
INNER JOIN colecoes c ON p.id_colecao = c.id_colecao
INNER JOIN cores cor ON pv.id_cor = cor.id_cor
INNER JOIN tamanhos t ON pv.id_tamanho = t.id_tamanho
LEFT JOIN fornecedores f ON pv.id_fornecedor = f.id_fornecedor
WHERE pv.quantidade_estoque <= pv.quantidade_minima;

-- View: Vendas com Detalhamento
CREATE VIEW v_vendas_detalhadas AS
SELECT 
  v.id_venda,
  v.data_venda,
  c.nome AS cliente,
  c.cpf,
  u.nome AS vendedor,
  p.nome AS produto,
  cor.nome AS cor,
  t.valor AS tamanho,
  iv.quantidade,
  iv.preco_unitario,
  iv.desconto_percentual,
  iv.subtotal,
  v.valor_total,
  v.status
FROM vendas v
INNER JOIN clientes c ON v.id_cliente = c.id_cliente
INNER JOIN usuarios u ON v.id_usuario = u.id_usuario
INNER JOIN item_venda iv ON v.id_venda = iv.id_venda
INNER JOIN produto_variacao pv ON iv.id_variacao = pv.id_variacao
INNER JOIN produtos p ON pv.id_produto = p.id_produto
INNER JOIN cores cor ON pv.id_cor = cor.id_cor
INNER JOIN tamanhos t ON pv.id_tamanho = t.id_tamanho;

-- View: Promoções Ativas
CREATE VIEW v_promocoes_ativas AS
SELECT 
  id_promocao,
  nome,
  descricao,
  percentual_desconto,
  data_inicio,
  data_fim,
  DATEDIFF(data_fim, NOW()) AS dias_restantes
FROM promocoes
WHERE data_inicio <= NOW()
AND data_fim >= NOW()
AND ativa = TRUE;

-- ============================================================
-- FIM DO SCRIPT
-- ============================================================
-- Total de tabelas: 14
-- Total de views: 3
-- Total de stored procedures: 3
-- Normalização: 3FN completa
-- Backup recomendado: Diariamente às 23:00
-- ============================================================