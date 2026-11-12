# Daily Logistics One Page

### Automação de Indicadores Logísticos | n8n

Projeto desenvolvido pela área de **Projetos Logística**, com o objetivo de consolidar indicadores operacionais em uma visão única e automatizada, utilizando o n8n como plataforma de orquestração.

## Objetivo

Centralizar a execução das consultas, o tratamento dos dados e a geração de informações para acompanhamento da operação logística.

## Tecnologias

- **n8n:** orquestração e automação dos processos.
- **SQL Server:** extração e consulta de dados operacionais.
- **JavaScript:** transformação e tratamento dos dados nos nós do n8n.
- **HTML/CSS:** apresentação visual das informações.

## Estrutura do repositório

| Diretório | Descrição |
|---|---|
| `workflows/` | Workflow oficial utilizado em produção |
| `workflows/archive/` | Versões anteriores do desenvolvimento |
| `sql/` | Consultas SQL utilizadas no projeto |
| `docs/` | Documentação funcional e técnica |
| `preview/` | Arquivos de pré-visualização da interface |

## Status

**Em produção**

O arquivo principal do workflow está disponível em `workflows/daily_logistics_one_page.json`.

## Implantação

1. Acessar o ambiente n8n.
2. Importar o arquivo JSON do workflow.
3. Configurar as credenciais e conexões necessárias.
4. Validar os nós de consulta e transformação.
5. Realizar uma execução de teste.
6. Ativar o workflow após a validação.

**Observação:** a importação do JSON não configura automaticamente credenciais ou dependências externas.

## Histórico de versões

As versões anteriores do workflow ficam armazenadas em `workflows/archive/`, para rastreabilidade das alterações e consulta técnica.

As alterações oficiais são documentadas em `CHANGELOG.md`.

## Responsável

**Projetos Logística — Grupo Soma**
