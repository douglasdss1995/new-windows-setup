-- =============================================================================
-- 01-init-db.sql — Inicialização do PostgreSQL
-- Executado automaticamente na primeira criação do container.
-- =============================================================================

-- Extensões úteis
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- geração de UUIDs
CREATE EXTENSION IF NOT EXISTS "pg_trgm";    -- busca por similaridade de texto

DO $$
BEGIN
  RAISE NOTICE 'PostgreSQL inicializado com sucesso!';
END $$;
