# README file

# SupportResistanceAI.ex5 📈

**SupportResistanceAI.ex5** é um indicador para **MetaTrader 5** projetado para contratos futuros (índices, commodities, moedas, energia).  
O indicador plota níveis de preço considerados essenciais para operações intraday e swing, evitando excesso de linhas no gráfico.

---

## Principais níveis desenhados

| Cor padrão | Nível gerado | Descrição | Utilidade prática |
|------------|--------------|-----------|-------------------|
| 🔵 **DodgerBlue** | **HiPrev / LoPrev** | Máxima e mínima do **dia anterior** | Pontos clássicos de rompimento/reversão intraday |
|            | **HiToday / LoToday** (tracejadas) | Máxima/mínima **em formação no dia atual** | Range que o dia está construindo |
| 🟡 **Gold** | **HiWeekPrev / LoWeekPrev** | Alta/baixa da **semana passada** | Suportes e resistências de swing |
|            | **HiWeek / LoWeek** (tracejadas) | Alta/baixa provisória da **semana atual** | Range semanal em formação |
| 🟠 **Orange** | **PP** (linha grossa) | Pivot Point do **dia anterior** | Eixo de equilíbrio diário |
|            | **R1 / R2** | Resistências derivadas do PP | Alvos / barreiras superiores |
|            | **S1 / S2** | Suportes derivados do PP | Alvos / barreiras inferiores |
| ⚪ **Silver** (pontilhado) | **ADR_UP / ADR_DN** | Projeção da **ADR** (Average Daily Range) média dos últimos *LookbackDays* | Alvos prováveis de alcance diário |

---

## Parâmetros (aba *Inputs*)

| Parâmetro | Padrão | Função |
|-----------|--------|--------|
| `LookbackDays` | `10` | Dias usados para calcular ADR |
| `MaxLinesPerGroup` | `4` | Máx. de linhas por categoria |
| `DayColor` | DodgerBlue | Cor dos níveis diários |
| `WeekColor` | Gold | Cor dos níveis semanais |
| `PivotColor` | Orange | Cor dos pivôs |
| `ADRColor` | Silver | Cor das projeções ADR |
| `ADRStyle` | Dot | Estilo da linha ADR |
| `ADR_Projection_Percent` | `100` | Percentual da ADR projetado (100 % = ADR completa) |

---

## Instalação

1. Abra **MetaEditor** (F4 no MT5).  
2. Crie **Arquivo → Novo → Indicador personalizado** e nomeie `Futures_SR_Toolkit`.  
3. Cole o código `Futures_SR_Toolkit.mq5` e compile (`F7`).  
4. No MT5, arraste **Navegador → Indicadores → Personalizados → Futures_SR_Toolkit** para o gráfico desejado.  
5. Ajuste parâmetros se necessário.

---

## Uso prático

- **Rompimento de HiPrev/LoPrev** → gatilho para continuação.  
- **PP + R1/S1** → pontos de retração/extensão para parciais.  
- **ADR_UP/DN** → metas prováveis de alcance diário; úteis para take‑profit ou reversão no fim do range.  
- **Níveis semanais** reforçam contextos de rompimento mais amplo.

Combine estes níveis com price action, volume ou seus indicadores favoritos para decisões de maior probabilidade em futuros.



