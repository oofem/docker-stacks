reset
set autoscale

set terminal pdfcairo enhanced size 4,3 font "Times,14" linewidth 1
set output "L_sigma.pdf"
#
set xlabel"Displacement [mm]"
set xr [0:0.08]
set xtics 0.01 nomirror
#
set ylabel"Stress [MPa]"
set yr [0:700.]
set ytics 100 nomirror
#
set border lw 1.5
#
set key top left
set key font ",14" spacing 1.0
set key width 2
#
plot \
'output.dat' using ( ($2)*1e3):($4) title 'Load vs. stress' with linespoints dt 1 lc 6 pt 5 ps 0.5 lw 2.
set output
