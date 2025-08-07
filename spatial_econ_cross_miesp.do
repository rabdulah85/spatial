
clear 
set more off

cd "/Users/rabdulah/Downloads/MIE_UNDIP_20250806"

global out "/Users/rabdulah/Downloads/MIE_UNDIP_20250806"

global data "/Users/rabdulah/Downloads/MIE_UNDIP_20250806"

log using "/Users/rabdulah/Downloads/MIE_UNDIP_20250806/jateng_cross.smcl"

/*/Install  command 
ssc install spmat, replace 
ssc install grmap, replace
ssc install spshape2dta, replace 
ssc install spatwmat, replace
*/


********************************************
//Setup Data//
********************************************

//Step 1. Extract Zip File berisi data shp (shape file). Data ini berisi keterangan informasi latitude dan longitude kabupaten/kota. 

unzipfile indo_district514.zip, replace

//Setelah ekstraksi file selesai, semua file hasil ekstraksi dipindahkan ke folder utama working direktori. Jika file hasil ekstraksi masih disimpah di sub folder hasil unzip  indo_district514.zip, maka command STATA tidak bisa membaca karena working direktori berada di folder utama, bukan sub folder hasil ekstraksi zip file.


//Step 2. Transform data .shp (spatial) ke format .dta (STATA format)

spshape2dta Indo_district514_2016, replace

//Load shapefile hasil konversi dan pilih Provinsi Jawa Tengah
use Indo_district514_2016.dta, clear
keep if province == "JAWA TENGAH"


//Step 3. Deklarasikan dataset sebagai data spasial


spset 



//Step 4. Buat kode unk untuk keperluan merging data spasial dengan data indikator penelitian yang akan digunakan 

egen unik_id = concat(prov_id districtno)
destring unik_id, replace



//Step 5. Merging spasial data dengan data indikator penelitian yang akan digunakan 

merge 1:1 unik_id using "$data/data_jateng.dta"

drop _merge


// Step 6. Save data (data siap olah)
save data_jateng_ready, replace 


********************************************
//Membuat Matriks//
********************************************

// Step 7. Buat Matrix W 

//Matrix yang dipakai adalaha jenis contiguity

spmat contiguity W_jateng using indo_district514_2016_shp, id(_ID) normalize(row) replace
spmat summarize W_jateng
spmat summarize W_jateng, links
spmat getmatrix W_jateng mW_jateng

mata

mW_jateng

end


* 7.1 Simpan matriks spmatrix dalam file
spmat export W_jateng using "$data/W_jateng_temp.txt", noid replace

* 7.2 Impor sebagai dataset
import delimited "$data/W_jateng_temp.txt", delim(space) rowrange(2) clear

* 7.3. Simpan sebagai dta
save "$data/W_jateng_temp.dta", replace

* 7.4. Buat kembali matriks W dengan spatwmat (ini yang bisa dibaca spatgsa!)
spatwmat using "$data/W_jateng_temp.dta", name(W_jateng)

dir



********************************************
//Exploratory Spatual Data Analysis (ESDA)//
********************************************


// Step 8. Membuat Peta


use data_jateng_ready , replace


//gen lnwage
forvalues y = 2002/2011 {
    gen lnwage`y' = ln(wage`y')
}



// 1. Indeks Gini
grmap ineq2002, title (Indeks Gini di Jawa Tengah Tahun 2002)
graph export "map_gini_2002.png", width(2000) replace

grmap ineq2011, title (Indeks Gini di Jawa Tengah Tahun 2011)
graph export "map_gini_2011.png", width(2000) replace



// 2. UMR (Upah Minimum Regional)
grmap lnwage2002, title("UMR Kabupaten/Kota di Jawa Tengah Tahun 2002")
graph export "map_wage2002.png", width(2000) replace

grmap lnwage2011, title("UMR Kabupaten/Kota di Jawa Tengah Tahun 2011")
graph export "map_wage2011.png", width(2000) replace

// 3. Indeks Pembangunan Manusia (HDI)
grmap hdi2002, title("Indeks Pembangunan Manusia di Jawa Tengah Tahun 2002")
graph export "map_hdi2002.png", width(2000) replace

grmap hdi2011, title("Indeks Pembangunan Manusia di Jawa Tengah Tahun 2011")
graph export "map_hdi2011.png", width(2000) replace

// 4. Pertumbuhan Ekonomi (dengan variabel y2002/y2011)
grmap y2002, title("Pertumbuhan Ekonomi di Jawa Tengah Tahun 2002 (%)")
graph export "map_y2002.png", width(2000) replace

grmap y2011, title("Pertumbuhan Ekonomi di Jawa Tengah Tahun 2011 (%)")
graph export "map_y2011.png", width(2000) replace

// 5. Persentase Kemiskinan (dengan variabel pov2002/pov2011)
grmap pov2002, title("Persentase Kemiskinan di Jawa Tengah Tahun 2002 (%)")
graph export "map_pov2002.png", width(2000) replace

grmap pov2011, title("Persentase Kemiskinan di Jawa Tengah Tahun 2011 (%)")
graph export "map_pov2011.png", width(2000) replace




* Step 9 : Global autocorrelation

//9.1 Moran I Kemiskinan (loop)

forvalues y = 2002/2011 {
   spatgsa pov`y', w(W_jateng) moran
   
}


preserve
clear
input year moranI p_value
2002   0.143   0.069
2003   0.111   0.113
2004   0.133   0.082
2005   0.163   0.049
2006   0.190   0.030
2007   0.174   0.040
2008   0.231   0.013
2009   0.218   0.017
2010   0.235   0.011
2011   0.258   0.007
end


* 2. Tambahkan dummy signifikan (p < 0.05)
gen signif = p_value < 0.05

* 3. Tambahkan titik marker hanya untuk signifikan
gen moran_sig = moranI if signif == 1

* 4. Gambar grafik
twoway ///
  (line moranI year, lcolor(blue) lwidth(medthick)) ///
  (scatter moran_sig year, msymbol(O) mcolor(red) msize(small) ///
   mlabel() mlabposition(0) mlabcolor(black)) ///
  , ///
  ytitle("Moran's I") xtitle("Year") ///
  title("Global Moran's I: Poverty 2002–2011") ///
  subtitle("Red circle = p-value < 0.05") ///
  note("Source: Author's calculation based on spatial weights matrix. Red dot mean significant at 0.05") ///
  xlabel(2002(1)2011, angle(0)) ///
  ylabel(, angle(0)) ///
  legend(off)
  
  graph export "moran_pov.png", width(2000) replace


restore
  
  
  
  

//9.2 Moran I HDI (loop)

forvalues y = 2002/2011 {
   spatgsa hdi`y', w(W_jateng) moran
   
}  


preserve

clear
input year moranI p_value
2002   0.201   0.022
2003   0.146   0.063
2004   0.094   0.141
2005   0.097   0.135
2006   0.083   0.163
2007   0.111   0.111
2008   0.099   0.131
2009   0.086   0.158
2010   0.080   0.169
2011   0.091   0.147
end

* Tambahkan dummy signifikan (p < 0.05)
gen signif = p_value < 0.05

* Tambahkan titik marker hanya untuk signifikan
gen moran_sig = moranI if signif == 1

* Gambar grafik
twoway ///
  (line moranI year, lcolor(blue) lwidth(medthick)) ///
  (scatter moran_sig year, msymbol(O) mcolor(red) msize(small) ///
   mlabel() mlabposition(0) mlabcolor(black)) ///
  , ///
  ytitle("Moran's I") xtitle("Year") ///
  title("Global Moran's I: IPM Jawa Tengah 2002–2011") ///
  subtitle("Red circle = p-value < 0.05") ///
  note("Source: Author's calculation based on spatial weights matrix. Red dot mean significant at 0.05") ///
  xlabel(2002(1)2011, angle(0)) ///
  ylabel(, angle(0)) ///
  legend(off)
  
  graph export "moran_ipm.png", width(2000) replace


restore
  



//9.3 Moran I Indeks Gini (loop)

forvalues y = 2002/2011 {
   spatgsa ineq`y', w(W_jateng) moran
   
}  

preserve

clear
input year moranI p_value
2002   0.035   0.286
2003   0.327   0.001
2004   0.147   0.064
2005   0.273   0.005
2006   0.133   0.076
2007  -0.058   0.404
2008   0.030   0.303
2009   0.010   0.362
2010   0.096   0.139
2011   0.273   0.005
end


* Tambahkan dummy signifikan (p < 0.05)
gen signif = p_value < 0.05

* Tambahkan titik marker hanya untuk signifikan
gen moran_sig = moranI if signif == 1

* Gambar grafik
twoway ///
  (line moranI year, lcolor(blue) lwidth(medthick)) ///
  (scatter moran_sig year, msymbol(O) mcolor(red) msize(small) ///
   mlabel() mlabposition(0) mlabcolor(black)) ///
  , ///
  ytitle("Moran's I") xtitle("Year") ///
  title("Global Moran's I: Indeks Gini Jawa Tengah 2002–2011") ///
  subtitle("Red circle = p-value < 0.05") ///
  note("Source: Author's calculation based on spatial weights matrix. Red dot mean significant at 0.05") ///
  xlabel(2002(1)2011, angle(0)) ///
  ylabel(, angle(0)) ///
  legend(off)

  graph export "moran_gini.png", width(2000) replace



restore






//9.4 Moran I Pertumbuhan Ekonomi (loop)

forvalues y = 2002/2011 {
   spatgsa y`y', w(W_jateng) moran
   
}  


preserve

clear
input year moranI p_value
2002   0.174   0.034
2003   0.265   0.006
2004   0.117   0.094
2005   0.057   0.209
2006   0.074   0.186
2007   0.081   0.172
2008   0.241   0.010
2009   0.054   0.215
2010   0.061   0.202
2011   0.075   0.176
end

* Tambahkan dummy signifikan (p < 0.05)
gen signif = p_value < 0.05

* Tambahkan titik marker hanya untuk signifikan
gen moran_sig = moranI if signif == 1

* Gambar grafik
twoway ///
  (line moranI year, lcolor(blue) lwidth(medthick)) ///
  (scatter moran_sig year, msymbol(O) mcolor(red) msize(small) ///
   mlabel() mlabposition(0) mlabcolor(black)) ///
  , ///
  ytitle("Moran's I") xtitle("Year") ///
  title("Global Moran's I: Pertumbuhan Ekonomi Jawa Tengah 2002–2011") ///
  subtitle("Red circle = p-value < 0.05") ///
  note("Source: Author's calculation based on spatial weights matrix. Red dot mean significant at 0.05") ///
  xlabel(2002(1)2011, angle(0)) ///
  ylabel(, angle(0)) ///
  legend(off)

   graph export "moran_growth.png", width(2000) replace

 
  
restore
 
 
 
//9.5 Moran I Wage/UMR (loop)
  
 forvalues y = 2002/2011 {
   spatgsa lnwage`y', w(W_jateng) moran
   
}

preserve
clear
input year moranI p_value
2002   0.162   0.048
2003   0.177   0.038
2004   0.276   0.002
2005   0.416   0.000
2006   0.227   0.011
2007   0.154   0.056
2008   0.347   0.001
2009   0.558   0.000
2010   0.472   0.000
2011   0.488   0.000
end


* Tambahkan dummy signifikan (p < 0.05)
gen signif = p_value < 0.05

* Tambahkan titik marker hanya untuk signifikan
gen moran_sig = moranI if signif == 1

* Gambar grafik
twoway ///
  (line moranI year, lcolor(blue) lwidth(medthick)) ///
  (scatter moran_sig year, msymbol(O) mcolor(red) msize(small) ///
   mlabel() mlabposition(0) mlabcolor(black)) ///
  , ///
  ytitle("Moran's I") xtitle("Year") ///
  title("Global Moran's I: UMR di Jawa Tengah 2002–2011") ///
  subtitle("Red circle = p-value < 0.05") ///
  note("Source: Author's calculation based on spatial weights matrix. Red dot mean significant at 0.05") ///
  xlabel(2002(1)2011, angle(0)) ///
  ylabel(, angle(0)) ///
  legend(off)

   graph export "moran_umr.png", width(2000) replace

 
restore


********************
//Analisa Regresi//
********************


//10. Melakukan diagnosa spasial dependensi dari regresi OLS. 

*10.1 Panggil kembali matrik yang sudah dibuat

spmatrix create contiguity W_jateng, normalize(row) replace

* Cek file matrix 

spmatrix dir




*10.2 Diagnosa selain Global Moran, apakah perlu regresi spasial lanjutan atau tidak. 
	
//Jalankan regresi OLS untuk variabel tahun 2011 (Cross Section)

//10.2.1. Modelnya adalah determinan ketimpangna di Jawa Tengah tahun 2011. Variable dependennya adalah indeks gini. Variable independentnya meliputi pertumbuhan ekonomi (y), upah minimum regional (UMR), Indeks Pembangunan Manusia (IPM) dan kemiskinan (pov). 


reg  ineq2011 y2011 lnwage2011 hdi2011  pov2011, ro


//10.2.2. Jalankan uji diagnostik spasial untuk tahun 2011 dalam rangka memilih model spasial mana yang tepat apakah spatial error, spatial lag atau dua-duanya
 
spatdiag, weights(W_jateng)




//10.2.3. Check distribusi residual

*swilk test
reg  ineq2011 y2011 lnwage2011 hdi2011  pov2011, ro
predict res, residuals 
swilk res


* A normal quantile-quantile plot (Q-Q plot) 
qnorm res

graph export "qq_plot_residual.png", width(2000) replace

* Histogram 
histogram res, normal

graph export "hist_residual.png", width(2000) replace




//11. Regresi Spasial. 
//Ada dua jenis spesifikasi yakni maximum likelihoof (ml) dan gs2sls. Hasil estimasi normalitas residual model OLS menunjukkan residual terdistriusi normal. MOdel estimasi ml menjadi preferensi utama

//Ada dua command yakni spreg dan spregress. Berikut contoh perbandingan penulisan command untuk spreg dan spregress dalam spesifikasi Spatial Durbin Model (SDM). 

*spreg ml depvar indepvars, id(idvar) dlmat(W) ilmat(W)
*spregress depvar indepvars, ml dvarlag(W) ivarlag(W: vars)




//Model 1 : SAR (spatial lag di variable Y)
spregress ineq2011 y2011 lnwage2011 hdi2011 pov2011, ml dvarlag(W_jateng)
estat impact

display "AIC = " 2*e(ll) - 2*e(k)
display "Log-likelihood = " e(ll)


//Model 2 : SLX (spatial lag di variable x)
spregress ineq2011 y2011 lnwage2011 hdi2011 pov2011, ml ivarlag(W_jateng:y2011)
estat impact

display "AIC = " 2*e(ll) - 2*e(k)
display "Log-likelihood = " e(ll)



//Model 3 : SEM (spatial lag di error)
//Beberapa catatan dalam estimasi model SEM menggunakn 
// Model SEM tidak bisa menghitung direct and indirect impact
spreg ml ineq2011 y2011 lnwage2011 hdi2011 pov2011, id(_ID) elmat(W_jateng)

display "AIC = " 2*e(ll) - 2*e(k)
display "Log-likelihood = " e(ll)


//Model 4 :  SDM (spatial lag di variable Y dan X (independent)

spregress ineq2011 y2011 lnwage2011 hdi2011 pov2011, ///
     ml ///
     dvarlag(W_jateng) ///
     ivarlag(W_jateng: y2011 lnwage2011 hdi2011 pov2011)
estat impact


display "AIC = " 2*e(ll) - 2*e(k)
display "Log-likelihood = " e(ll)

*********
//END //
*********
	
	
	
log close 	



/*/Lisa 

spatlsa pov2011, weights(W_jateng) moran id(_ID) sort


matrix list r(Moran) 
matrix Moran=r(Moran)
svmat Moran

* Hitung nilai spatial lag
spgenerate lag_pov2011 = W_jateng*pov2011


* Standardize nilai asli dan spatial lag
egen z_pov2002 = std(pov2011)
egen z_lag_pov2002 = std(lag_pov2011)


twoway (scatter z_lag_pov2011 z_pov2011, ///
          msymbol(circle) mcolor(blue) ///
          title("Moran Scatterplot") ///
          xtitle("Standardized POV 2002") ///
          ytitle("Spatial Lag POV 2002")) ///
       (lfit z_lag_pov2002 z_pov2002, lcolor(red)), ///
       xline(0, lpattern(dash)) yline(0, lpattern(dash))
	   

* Buat variabel dummy klasifikasi
gen lisa_type = .

* High-High (HH)
replace lisa_type = 1 if z_pov2011 > 0 & z_lag_pov2011 > 0 & Moran5 < 0.05

* Low-Low (LL)
replace lisa_type = 2 if z_pov2011 < 0 & z_lag_pov2011 < 0 & Moran5 < 0.05

* High-Low (HL)
replace lisa_type = 3 if z_pov2011 > 0 & z_lag_pov2011 < 0 & Moran5 < 0.05

* Low-High (LH)
replace lisa_type = 4 if z_pov2011 < 0 & z_lag_pov2011 > 0 & Moran5 < 0.05

* Not significant
replace lisa_type = 0 if Moran5 >= 0.05


* Simpan ke file sementara
tempfile lisa
save `lisa', replace

save "$data/lisa_jateng_2011.dta", replace


* Load shapefile
use "$data/lisa_jateng_2011.dta", clear

* Merge hasil LISA
merge 1:1 _ID using lisa_jateng, nogen

drop if lisa_type==.



* Atur warna LISA
label define lisa_lbl 0 "Not significant" 1 "High-High" 2 "Low-Low" 3 "High-Low" 4 "Low-High"
label values lisa_type lisa_lbl


	
grmap lisa_type, ///
    id(_ID) ///
    fcolor(white red blue pink purple) ///
    ocolor(black .. .. .. ..) osize(vvthin .. .. .. ..) ///
    legend(order(1 "High-High" 2 "Low-Low" 3 "High-Low" 4 "Low-High" 0 "Not Significant")) ///
    legtitle("LISA Cluster (Poverty 2002)") ///
    title("LISA Cluster Map of Poverty 2002") ///
    note("Source: Author calculation using Moran's I")
	
	
	 
*/
	 
	 
	 
	 
	 
	
	












	
	
