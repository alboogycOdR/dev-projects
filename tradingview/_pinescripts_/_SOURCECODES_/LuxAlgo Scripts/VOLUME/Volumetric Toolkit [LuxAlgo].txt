// This work is licensed under a Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0) https://creativecommons.org/licenses/by-nc-sa/4.0/
// © LuxAlgo

//@version=5
indicator("Volumetric Toolkit [LuxAlgo]", "LuxAlgo - Volumetric Toolkit", overlay = true, max_lines_count = 500, max_boxes_count = 500)
//------------------------------------------------------------------------------
//Settings
//-----------------------------------------------------------------------------{
//Ranges Of Interest
showRoi = input(true, 'Show Ranges Of Interest'       , group = 'Ranges Of Interest')
roiLength = input(50, 'Length'                        , group = 'Ranges Of Interest')
roiCss = input(#b2b5be, 'Colors', inline = 'roicss' , group = 'Ranges Of Interest')
roiAvg = input(#5d606b, ''      , inline = 'roicss' , group = 'Ranges Of Interest')

//Impulses
showImp = input(true, 'Show Impulses'                 , group = 'Impulses')
impLength = input(20, 'Length'                        , group = 'Impulses')
impBull = input(#089981, 'Colors', inline = 'loicss', group = 'Impulses')
impBear = input(#f23645, ''      , inline = 'loicss', group = 'Impulses')

//Levels Of Interest
showLoi = input(false, 'Show'       , inline = 'loishow', group = 'Levels Of Interest')
loiShowLast = input(5, ''           , inline = 'loishow', group = 'Levels Of Interest')
loiLength = input(20, 'Length'                          , group = 'Levels Of Interest')
loiBull = input(#2962ff, 'Colors', inline = 'loicss'  , group = 'Levels Of Interest')
loiBear = input(#f23645, ''      , inline = 'loicss'  , group = 'Levels Of Interest')

//Volume Divergences
showDiv = input(false, 'Show Divergences'              , group = 'Divergences')
divLength = input(10, 'Length'                        , group = 'Divergences')
divBull = input(#5b9cf6, 'Colors', inline = 'vicss' , group = 'Divergences')
divBear = input(#ff5d00, ''      , inline = 'vicss' , group = 'Divergences')

//-----------------------------------------------------------------------------}
//Main Variables
//-----------------------------------------------------------------------------{
n = bar_index
v = volume
trail_mean = ta.cum(v) / n

//-----------------------------------------------------------------------------}
//Levels Of Interest
//-----------------------------------------------------------------------------{
var loi_lvls = array.new<line>(0)
var loi_vals = array.new<float>(0)

loi_phv = ta.pivothigh(v, loiLength, loiLength)

if loi_phv and showLoi
    avg = hl2[loiLength]
    lvl = line.new(time[loiLength], avg, time, avg, xloc.bar_time, extend.right)
    loi_lvls.push(lvl)
    loi_vals.push(avg)

    if loi_lvls.size() > loiShowLast
        loi_lvls.get(0).delete()
        loi_lvls.shift()
        loi_vals.shift()

if barstate.islast
    for element in loi_lvls
        element.set_color(color.from_gradient(element.get_y1(), loi_vals.min(), loi_vals.max(), loiBull, loiBear))

//-----------------------------------------------------------------------------}
//Ranges Of Interest
//-----------------------------------------------------------------------------{
var float roi_upper = na
var line  roi_avg   = na
var float roi_lower = na
var roi_os = 0

rhv = ta.highest(v, roiLength)

if showRoi
    if rhv == v
        roi_avg := line.new(n, hl2, n, hl2, color = roiAvg, style = line.style_dashed)
    else
        roi_avg.set_x2(n)

roi_upper := rhv == v and showRoi ? high : roi_upper
roi_lower := rhv == v and showRoi ? low : roi_lower

//-----------------------------------------------------------------------------}
//Impulses
//-----------------------------------------------------------------------------{
imp_upv = ta.highest(v, impLength)
imp_up = ta.highest(impLength)
imp_dn = ta.lowest(impLength)

bull_imp = imp_upv > imp_upv[1] and imp_up > imp_up[1] and showImp
bear_imp = imp_upv > imp_upv[1] and imp_dn < imp_dn[1] and showImp

//-----------------------------------------------------------------------------}
//Volume Divergences
//-----------------------------------------------------------------------------{
var ph_y1 = 0., var pl_y1 = 0., var phv_y1 = 0., var x1 = 0

ph  = ta.pivothigh(divLength, divLength)
pl  = ta.pivotlow(divLength, divLength)
phv = ta.pivothigh(volume, divLength, divLength)

if phv and showDiv
    if phv < phv_y1 and high[divLength] > ph_y1 and ph
        line.new(n - divLength, high[divLength], x1, ph_y1, color = divBull)
    else if phv < phv_y1 and low[divLength] < pl_y1 and pl
        line.new(n - divLength, low[divLength], x1, pl_y1, color = divBear)

    phv_y1 := phv
    ph_y1  := high[divLength]
    pl_y1  := low[divLength]
    x1     := n - divLength

//-----------------------------------------------------------------------------}
//Plots
//-----------------------------------------------------------------------------{
//ROI
plot(roi_upper, 'Upper', rhv == v ? na : roiCss)
plot(roi_lower, 'Lower', rhv == v ? na : roiCss)

//Impulses
plotcandle(high, high, low, low
  , color = color(na)
  , wickcolor = color(na)
  , bordercolor = bull_imp ? impBull : color(na)
  , display = display.all - display.status_line)

plotcandle(high, high, low, low
  , color = color(na)
  , wickcolor = color(na)
  , bordercolor = bear_imp ? impBear : color(na)
  , display = display.all - display.status_line)

//-----------------------------------------------------------------------------}