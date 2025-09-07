// This work is licensed under a Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0) https://creativecommons.org/licenses/by-nc-sa/4.0/
// © LuxAlgo

//@version=5
indicator("Volume Delta Trailing Stop [LuxAlgo]", shorttitle="LuxAlgo - Volume Delta Trailing Stop", overlay=true)

//-----------------------------------------------------------------------------}
//Settings
//-----------------------------------------------------------------------------{
res             = input.string('1'  ,     'LTF'   ,           options=['1S','5S','10S', '15S','30S','1' ])
trig            = input.string('H/L' ,   'Trigger' ,           options=[    'H/L'      ,    'Close'      ])
adj             = input.string(        'Adjustment', 'Δ line', options=[ 'Adjustment'  ,  'Mult of TR'   ])
perc            = input.float ( 0.0  , 'Adjustment',           minval =0,          step=0.01             ) / 100
mult            = input.float (  10  , 'Mult of TR',           minval =1,          step=0.1              ) 
inputSource     = input.string('open',  'based on:',           options=[   'open'      , 'previous close'])
neutral_green   = input.bool  (true  , '"Neutral-Volume" is considered "Up-Volume"')

gr              = '           Up    -    Down'     , gr2    = '        Barcolor'

colUp           = input.color(#009688,   '   '   , inline = 'c', group=gr )
colDn           = input.color(#F23645,   ' - '   , inline = 'c', group=gr )

BclUp           = input.color(#3e89fa,   '   '   , inline = 'c', group=gr2)
BclDn           = input.color(#ff9531,   ' - '   , inline = 'c', group=gr2)

wick            = trig == 'H/L'
ad              = adj  == 'Adjustment'

//-----------------------------------------------------------------------------}
//Variables
//-----------------------------------------------------------------------------{
var int pos = 0, var int dir = na, var float sl = na, var float en = na, var float tLine = na, var float dLine = na

//-----------------------------------------------------------------------------}
//Calculations
//-----------------------------------------------------------------------------{
o  = inputSource == 'open' ? open : nz(close[1])

up = neutral_green ? close >= o : close > o
dn =                              close < o

[bV, sV]        
 = request.security_lower_tf(
   syminfo.tickerid, res
 ,[
   up ? volume : 0
 , dn ? volume : 0
  ]
 )

upV = bV  .sum() 
dnV = sV  .sum() 
dV  = upV - dnV 

n   = bar_index
tr  = ta.tr * mult
mx  = math.max(open, close) 
mn  = math.min(open, close)

bullishBear = dV > 0 and dn 
bearishBull = dV < 0 and up

dir   := bullishBear ?   1  : bearishBull?  -1 :  dir
tLine := bullishBear ? high : bearishBull? low : tLine

ch     = ta.change(tLine)
cp     = ta.change( pos )

if pos == 0 
    if (wick ? high : close) > tLine 
     and dir==  1 and   o    < tLine
        pos :=  1
        sl  := low    
        en  := (wick ? tLine : close)
        alert('signal up'  , wick ? alert.freq_once_per_bar : alert.freq_once_per_bar_close)
        
    if (wick ? low  : close) < tLine 
     and dir== -1 and   o    > tLine
        pos := -1
        sl  := high    
        en  := (wick ? tLine : close)
        alert('signal down', wick ? alert.freq_once_per_bar : alert.freq_once_per_bar_close)

if pos ==  1
    if ch and not bearishBull
        lv   = ad ? low  * (1 - perc) : low  - tr 
        sl  := math.max(sl, math.min(lv, nz(tLine[1], tLine)))
    if close < sl 
        sl  := na 
        pos := 0
        alert('TS-line broken down', alert.freq_once_per_bar_close)

if pos == -1
    if ch and not bullishBear
        lv   = ad ? high * (1 + perc) : high + tr
        sl  := math.min(sl, math.max(lv, nz(tLine[1], tLine)))
    if close > sl 
        sl  := na 
        pos := 0
        alert('TS-line broken up'  , alert.freq_once_per_bar_close)

if cp 
    switch pos 
        1  => 
            line.new (n -2, en, n -1, en, color=colUp, style=line.style_solid, width=2) 
        -1 => 
            line.new (n -2, en, n -1, en, color=colDn, style=line.style_solid, width=2) 

dLine := pos == 0 ? bearishBull ? low : bullishBear ? high : dLine : na

//-----------------------------------------------------------------------------}
//Plot/Fill/Barcolor
//-----------------------------------------------------------------------------{
plot(dLine, color=color.new(chart.fg_color, 25), style = plot.style_steplinebr)

l1 = plot(pos ==  0              and pos[1] !=  0  ? sl[1] : sl
 , color= pos ==  1 or (pos == 0 and pos[1] ==  1) ? colUp 
 :        pos == -1 or (pos == 0 and pos[1] == -1) ? colDn : color(na), style=plot.style_linebr, linewidth=2)
l2 = plot(pos ==  1 ?   mn 
 :        pos == -1 ?   mx : na                    , color=color.new(color.blue, 100), display=display.none) 
 
fill(l1, l2, color=close > sl or close[1] > sl[1] ? color.new(colUp, 80) : color.new(colDn, 80))

barcolor(
  bullishBear ? BclUp :
  bearishBull ? BclDn : na
 )

//-----------------------------------------------------------------------------}