// This work is licensed under a Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0) https://creativecommons.org/licenses/by-nc-sa/4.0/
// © LuxAlgo

//@version=5
indicator("SuperTrend Polyfactor Oscillator [LuxAlgo]", "LuxAlgo - SuperTrend Polyfactor Oscillator")
//-----------------------------------------------------------------------------}
//Settings
//-----------------------------------------------------------------------------{
length = input.int(10, minval = 2)
starting = input.float(1, 'Starting Factor', minval = 0)
increment = input.float(.5, minval = 0, step = .1)

normalize = input.string('None', options = ['None', 'Max-Min', 'Absolute Sum'])

//Style
mesh = input(true, inline = 'mesh', group = 'Style')
upCss = input.color(color.new(#089981, 90), '', inline = 'mesh', group = 'Style')
dnCss = input.color(color.new(#f23645, 90), '', inline = 'mesh', group = 'Style')

//-----------------------------------------------------------------------------}
//UDT's
//-----------------------------------------------------------------------------{
type supertrend
    float upper = hl2
    float lower = hl2
    float output
    float perf = 0
    float factor
    int trend = 0

//-----------------------------------------------------------------------------}
//Function
//-----------------------------------------------------------------------------{
norm(value, diffs, den)=>
    normalized = switch normalize
        'Max-Min' => (value - diffs.min()) / diffs.range()
        'Absolute Sum' => value / den
        => value

//-----------------------------------------------------------------------------}
//Supertrend
//-----------------------------------------------------------------------------{
var holder = array.new<supertrend>(0)
diffs = array.new<float>(0)

//Populate supertrend type array
if barstate.isfirst
    for i = 0 to 19
        holder.push(supertrend.new())

atr = ta.atr(length)

//Compute Supertrend for multiple factors
k = 0
den = 0.
factor = starting

for i = 0 to 19
    get_spt = holder.get(k)

    up = hl2 + atr * factor
    dn = hl2 - atr * factor
    
    get_spt.trend := close > get_spt.upper ? 1 : close < get_spt.lower ? 0 : get_spt.trend
    get_spt.upper := close[1] < get_spt.upper ? math.min(up, get_spt.upper) : up
    get_spt.lower := close[1] > get_spt.lower ? math.max(dn, get_spt.lower) : dn
    get_spt.output := get_spt.trend == 1 ? get_spt.lower : get_spt.upper

    diffs.push(close - get_spt.output)

    k += 1
    den += math.abs(close - get_spt.output)
    factor += increment

//Outputs
median = norm(diffs.median(), diffs, den)
stdev = normalize != 'Max-Min' ? norm(diffs.stdev(), diffs, den) : na

//-----------------------------------------------------------------------------}
//Plots
//-----------------------------------------------------------------------------{
//Mesh
plot(mesh ? norm(diffs.get(0), diffs, den) : na , color = diffs.get(0) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(1), diffs, den) : na , color = diffs.get(1) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(2), diffs, den) : na , color = diffs.get(2) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(3), diffs, den) : na , color = diffs.get(3) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(4), diffs, den) : na , color = diffs.get(4) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(5), diffs, den) : na , color = diffs.get(5) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(6), diffs, den) : na , color = diffs.get(6) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(7), diffs, den) : na , color = diffs.get(7) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(8), diffs, den) : na , color = diffs.get(8) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(9), diffs, den) : na , color = diffs.get(9) > 0 ? upCss : dnCss , style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(10), diffs, den) : na, color = diffs.get(10) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(11), diffs, den) : na, color = diffs.get(11) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(12), diffs, den) : na, color = diffs.get(12) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(13), diffs, den) : na, color = diffs.get(13) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(14), diffs, den) : na, color = diffs.get(14) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(15), diffs, den) : na, color = diffs.get(15) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(16), diffs, den) : na, color = diffs.get(16) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(17), diffs, den) : na, color = diffs.get(17) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(18), diffs, den) : na, color = diffs.get(18) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)
plot(mesh ? norm(diffs.get(19), diffs, den) : na, color = diffs.get(19) > 0 ? upCss : dnCss, style = plot.style_histogram, display = display.all - display.status_line, editable = false)

//Median
plot(median, 'Median', median > (normalize == 'Max-Min' ? .5 : 0) ? #90bff9 : #ffcc80)

//Stdev Area
up = plot(stdev, color = na, editable = false)
dn = plot(-stdev, color = na, editable = false)
fill(up, dn, color.new(#90bff9, 80), title = 'Stdev Area')

//-----------------------------------------------------------------------------}