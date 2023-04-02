clear all
set more off
capture log close

cd "G:\Drive\Research\ecdis_2nd_stage"

//******* Data Preparation *******//
//append the data of college application rules
import delimited "C:\Users\chihyu.tsou\Desktop\star_2nd_stage\org_data\RC5_校系分則(申請)2021.csv", bindquote(strict) varnames(1) maxquotedrows(100) stringcols(2 4) clear 
save "org_data\gsat_rule_2021.dta", replace

import delimited "C:\Users\chihyu.tsou\Desktop\star_2nd_stage\org_data\RC5_校系分則(申請)2011 ~ 2020.csv", bindquote(strict) varnames(1) maxquotedrows(100) stringcols(2 4) numericcols(16 19) clear
append using "org_data\gsat_rule_2021.dta", force

order totmul_rc5, after(scimul_rc5)
order totpstd_rc5, after(englsnpstd_rc5)
order xtraq_vsn_rc5, after(xtraq_oi_rc5)

replace depabbr_rc5 = "" if depabbr_rc5 == "NULL"
replace deptyp_rc5 = "" if deptyp_rc5 == "NULL"

rename cyr_rc5 cyr
rename depcd_rc5 depcd

save "org_data\gsat_rule.dta", replace

//create a dta file of field codes for college-departments
import delimited "org_data\JB_cross_MOE_app_100to110_0104.csv", stringcols(2 3) clear 
rename cyr_rc5 cyr
rename depcd_rc5 depcd
duplicates drop
duplicates drop cyr depcd, force

save "org_data\moecd_update_0104.dta", replace

//create a dta file of high school codes from Ministry of Education (MOE)
import delimited "org_data\HS_moe_jbcrc_crosswalk.csv", stringcols(2) 
save "org_data\hs_cd_moe.dta", replace

use "org_data\hs_cd_moe.dta", clear
keep if cyr == 2020
replace cyr = 2021
save "org_data\hs_cd_moe_2021.dta", replace

use "org_data\hs_cd_moe.dta", clear
append using "org_data\hs_cd_moe_2021.dta", force
save "org_data\hs_cd_moe_total.dta", replace

//append the data of college application results
import delimited "org_data\RC2_個人申請入學資料表2021.csv", clear
save "org_data\gsat_2021.dta", replace

import delimited "org_data\RC2_個人申請入學資料表2011 ~ 2020.csv", clear
append using "org_data\gsat_2021.dta", force

save "data\gsat_total", replace

//******* Data Merging *******//
use "data\gsat_total.dta", clear

rename cyr_rc2 cyr
split app_udep_rc2, parse("_")
rename app_udep_rc21 depcd
rename app_udep_rc22 uninm_rc5
rename app_udep_rc23 depnm_rc5

//merge with the data of college application rules
merge m:1 cyr depcd using "gsat_rule.dta"
gen app_udepnm = uninm_rc5+ "_" + depnm_rc5
tab app_udepnm if _merge == 2 //140 obs without college application rules
tab app_udepnm if _merge == 2 & ustrregexm(app_udepnm, "青年儲蓄") == 1 //133 obs with youth saving groups
tab app_udepnm if _merge == 2 & ustrregexm(app_udepnm, "青年儲蓄") == 0 //7 obs  
drop if _merge == 2
drop _merge
drop app_udepnm

//merge with the data of weighting rules of subjects including interviews, application materials, etc. in stage 2
merge m:1 cyr depcd using "p_gsat_update.dta"

gen app_udepnm = uninm_rc5+ "_" + depnm_rc5
tab app_udepnm if _merge == 1 //58699 obs from department of music and art without matched weighting rules of subjects
tab app_udepnm cyr if _merge == 1 

tab app_udepnm if _merge == 2 //140 obs weighting rules of subjects in stage 2 without applicants 
tab app_udepnm if _merge == 2 & ustrregexm(app_udepnm, "青年儲蓄") == 1 //133 obs with youth saving groups
tab app_udepnm if _merge == 2 & ustrregexm(app_udepnm, "青年儲蓄") == 0 //7 obs 
//the same results when merging with the data of college application rules
drop _merge

//merge with the data of field codes for departments
merge m:1 cyr depcd using "org_data\moecd_update_0104.dta" //all are perfectly matched
drop _merge

//merge with the data of high school codes from Ministry of Education (MOE)
split sssch_rc2, parse("_")
rename sssch_rc21 hs_cd_jb 
drop sssch_rc22

merge m:1 cyr hs_cd_jb using "org_data\hs_cd_moe_total.dta"

//list high schools without matched application data. 
list cyr hs_cd_jb hs_nm_jb hs_cd_moe hs_nm_moe if _merge == 2

//list high schools without Ministry of Education (MOE) school code
tab sssch_rc2 if _merge == 1
tab cyr sssch_rc2 if _merge == 1

tab hs_cd_jb if ustrregexm(sssch_rc2, "康橋") == 1, missing
gen hs_cd = hs_cd_jb
replace hs_cd = "178" if hs_cd == "269"

drop if _merge == 2
drop _merge

//******* Variable creation
//*** create a variable indicating passing stage 1
gen fst_pass = 1 if st1_rslt_rc2 == "通過"
replace fst_pass = 0 if fst_pass == .

//*** create a variable indicating passing stage 2 and getting admitted by the department
gen snd_pass = 1 if ustrregexm(acc_rc2, "正取") == 1 
replace snd_pass = 0 if ustrregexm(acc_rc2, "外加") == 1 | snd_pass == .

//*** generate id for individuals
//individuals
egen id = group(cyr gsatid_rc2)

//*** generate id for departments
//correct discrepancies of department names due to fullwidth and halfwidth parentheses
gen cor_app_udep_rc2 = ustrregexra(app_udep_rc2, "（", "(")
replace cor_app_udep_rc2 = ustrregexra(cor_app_udep_rc2, "）", ")")

//merge missing field codes for departments
merge m:1 cyr cor_app_udep_rc2 using "p_see_filled.dta"
drop _merge
drop top_uni public see

replace depnm_rc5 = ustrregexra(depnm_rc5, "（", "(")
replace depnm_rc5 = ustrregexra(depnm_rc5, "）", ")")

gen latest_moecd_scd2_union = latest_moecd_scd2
replace latest_moecd_scd2_union = latest_moecd_scd2_filled if latest_moecd_scd2 == ""

split latest_moecd_scd2_union, parse("_")
rename latest_moecd_scd2_union1 unicd_moe
drop latest_moecd_scd2_union2

egen dep_id = group(unicd_moe depnm_rc5)

//*** generate id for high schools
egen hs_id = group(hs_cd)

//*** generate codes for broad fields, fields and detailed fields
//broad field (filled)
gen b_fd = usubstr(latest_moecd_scd2_union, 6, 2)
egen bfd_id = group(b_fd)

//narrow field
gen n_fd = usubstr(latest_moecd_scd2_union, 6, 3)
egen nfd_id = group(n_fd)

//detailed field
gen d_fd = usubstr(latest_moecd_scd2_union, 6, 4)
egen dfd_id = group(d_fd)

//detailed-detailed field
gen dd_fd = usubstr(latest_moecd_scd2_union, 6, 5)
egen ddfd_id = group(dd_fd)

//*** school characteristics
//top universities
gen top_uni = 1 if ustrregexm(schnm_rc5, "國立臺灣大學|國立成功大學|國立清華大學|國立交通大學|國立中央大學|國立陽明大學|國立中山大學|國立中興大學|國立臺灣科技大學|國立政治大學|國立臺灣師範大學|長庚大學") == 1
replace top_uni = 0 if top_uni == .

//public / private universities 
gen public = 1 if ustrregexm(app_udep_rc2, "國立|市立") == 1
replace public = 0 if public == .

//*** department characteristics
//the number of applicants
bysort cyr unicd_moe depnm_rc5: gen appq = _N

//major choices exclusive for the underprivileged
gen up = 1 if ustrregexm(app_udep_rc2, "希望組|晨光組|興翼|成星|政星|旭日|揚帆|旋坤|向日葵|西灣|南星|璞玉|勵進|展翅|新芽|精進|飛揚|飛鳶|薪火|嘉星|展翅|揚鷹|翔飛|鯤鵬展翅") == 1
replace up = 0 if up == .

//*** whether the department belongs to STEM (*)
gen stem = ustrregexm(n_fd, "051|052|053|054|061|071|072|073")

//*** individual characteristics
//indigeneous people
gen indig = 1 if sttyp_rc2 == 1
replace indig = 0 if indig == .

//star high schools
gen star = ustrregexm(sssch_rc2, "132|102|292|105|450|100|289|402|101|700|400|430|127|802|103|801")

//the percentage of extra quotas the students used among all their major choices in stage 1
gen xtra1 = 1 if st1_xtra_rc2 == "通過"
replace xtra1 = 0 if xtra1 == .
bysort cyr gsatid_rc2: egen xtra1_use = mean(xtra1)

//the percentage of extra quotas the students used among all their major choices in stage 2
gen xtra2 = 1 if ustrregexm(acc_rc2, "外加") == 1
replace xtra2 = 0 if xtra2 == .
bysort cyr gsatid_rc2: egen xtra2_use = mean(xtra2)

//island
gen island = 1 if sttyp_rc2 == 2
replace island = 0 if island == .

//weighted GSAT grades
replace scrprop_gsat_rc5 = scrprop_gsat_rc5 * 100 if scrprop_gsat_rc5 < 1

gen gsat_gp_rc2_wt = gsat_chigp_rc2 * chiwt_rc5 + gsat_enggp_rc2 * engwt_rc5 + gsat_mathgp_rc2 * mathwt_rc5 + gsat_socgp_rc2 * socwt_rc5 + gsat_scigp_rc2 * sciwt_rc5

//alternative definitions of pexam_rc5
gen pexam_rc5_alt = 1 if p_practice > 0
replace pexam_rc5_alt = 0 if pexam_rc5_alt == .

save "ecdis_2nd_stage.dta", replace

//*** variable of interest
//the sum of non-blind screening test
gen p_see = p_interview + p_paper
gen see = p_see
replace see = 0 if p_see == .

//economically disadvantaged
gen ecdis = 1 if lictyp_rc2 == 1 | lictyp_rc2 == 2
replace ecdis = 0 if ecdis == .

//* linear interaction terms 
gen ecdis_see = ecdis * see

//* allow non-linear treatment effect of see
//1. create dummies for different ranges of see
//2. impose different functional forms

//categorical variables
gen see_cat = 25 if see <= 25 & see >= 0
replace see_cat = 50 if see <= 50 & see > 25
replace see_cat = 75 if see <= 75 & see > 50
replace see_cat = 100 if see <= 100 & see > 75

//quadratic functional forms
gen see2 = see ^ 2
gen ecdis_see2 = ecdis * see2

sysdir set PERSONAL "G:\Drive\Research\stata_pkgs"
sysdir set PLUS "G:\Drive\Research\stata_pkgs"

/******* descriptive statistics *******/
bysort cyr dep_id id: gen uniq = _n
preserve
keep if up == 0 & fst_pass == 1 & uniq == 1
bysort dep_id: gen dep_escrq_n = _N
tab dep_id //42 singletons

summarize ecdis sex_rc2 indig star admq_rc5 pexam_rc5 if dep_escrq_n > 1

summarize snd_pass if dep_escrq_n > 1 & ecdis == 1
summarize snd_pass if dep_escrq_n > 1 & sex_rc2 == 1
summarize snd_pass if dep_escrq_n > 1 & indig == 1
summarize snd_pass if dep_escrq_n > 1 & star == 1

bysort id: gen id_order = _n
summarize ecdis sex_rc2 indig star if dep_escrq_n > 1 & id_order == 1

bysort dep_id: gen dep_order = _n
summarize admq_rc5 pexam_rc5 if dep_escrq_n > 1 & dep_order == 1
restore

bysort id: gen id_n = _N
summarize id_n if dep_escrq_n > 1 & id_order == 1

preserve
drop if dep_escrq_n == 1 
duplicates drop id, force
summarize ecdis sex_rc2 indig star
restore

/******* baseline regression *******/
reghdfe snd_pass c.ecdis_see ecdis c.see sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "baseline.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//categorical variables
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "baseline.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//quadratic functional forms
reghdfe snd_pass ecdis_see2 ecdis_see ecdis see see2 sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "baseline.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(7)

//******* add uni-year fixed effects (uni common shocks) *******//
egen uni_id = group(unicd_moe)

reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id i.cyr i.uni_id#i.cyr) cluster(id)
outreg2 using "uni_nfd_fe.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//******* add detailed field-year fixed effects (detailed field common shocks) *******//
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id i.cyr i.dfd_id#i.cyr) cluster(id)
outreg2 using "uni_nfd_fe.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//*** combine uni-year and detailed field-year fixed effects
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id i.cyr i.uni_id#i.cyr i.dfd_id#i.cyr) cluster(id)
outreg2 using "uni_nfd_fe.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//******* allows different trends for departments *******//
gen cyr2 = cyr ^ 2
gen cyr3 = cyr ^ 3

reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 if up == 0 & fst_pass == 1 & uniq == 1, absorb(i.cyr dep_id#c.cyr) cluster(id)
outreg2 using "dep_trd.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 if up == 0 & fst_pass == 1 & uniq == 1, absorb(i.cyr dep_id#(c.cyr c.cyr2)) cluster(id)
outreg2 using "dep_trd.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 if up == 0 & fst_pass == 1 & uniq == 1, absorb(i.cyr dep_id#(c.cyr c.cyr2 c.cyr3)) cluster(id)
outreg2 using "dep_trd.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//******* balancing test *******//
//*** weighted GSAT grades
reghdfe gsat_gp_rc2_wt see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "rc.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//*** the applicants from outside islands
reghdfe island see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "rc.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//*** the number of applicants to departments passing stage 1
reghdfe escrq_rc5 see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "rc.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//bysort cyr unicd_moe depnm_rc5: egen escrq = total(fst_pass)

//******* alternative outcomes
//*** reject
gen reject = 1 if (ordering == . | ordering == 0) & fst_pass == 1 & snd_pass == 1
replace reject = 0 if reject == .

reghdfe reject see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & snd_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "ao.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)

//*** placement
reghdfe plcmt_rc2 see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & snd_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "ao.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)

//*** cancel
reghdfe cancel_rc2 see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & snd_pass == 1 & plcmt_rc2 == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "ao.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)

//*** placement with waiting lists
reghdfe plcmt_rc2 see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & (snd_pass == 1| ustrregexm(acc_rc2, "備取") == 1 & ustrregexm(acc_rc2, "外加") == 0) & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "ao.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)

//*** reject with waiting lists
reghdfe reject see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & (snd_pass == 1| ustrregexm(acc_rc2, "備取") == 1 & ustrregexm(acc_rc2, "外加") == 0) & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "ao.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)

//******* alternative definitions of economically disadvantaged 
//*** expand the definition of ecdis
bysort id: egen up_use = mean(up)
gen wpx = 1 if ecdis == 1 | up_use > 0
replace wpx = 0 if wpx == .

reghdfe snd_pass see_cat##wpx sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "wpx.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)

//*** restrict the definition of ecdis
gen ext_ecdis = 1 if lictyp_rc2 == 2
replace ext_ecdis = 0 if ext_ecdis == .

reghdfe snd_pass see_cat##ext_ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "wpx.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)

//******* use did_multiplegt as complementary tests *******//
keep if up == 0 & fst_pass == 1 & uniq == 1
bysort dep_id: gen dep_escrq_n = _N
//tab dep_id //42 singletons
drop if dep_escrq_n == 1 

bysort dep_id cyr ecdis: egen snd_pass_d = mean(snd_pass)
gen snd_pass_o = snd_pass_d if ecdis == 0
gen snd_pass_e = snd_pass_d if ecdis == 1
 
bysort dep_id cyr: fillmissing snd_pass_o
//replace snd_pass_o = 0 if snd_pass_o == .
bysort dep_id cyr: fillmissing snd_pass_e
//replace snd_pass_e = 0 if snd_pass_e == .
gen snd_pass_diff = snd_pass_e - snd_pass_o

//*** baseline regressions with reduced samples
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if snd_pass_o != . & snd_pass_e != ., absorb(dep_id) cluster(id)
outreg2 using "comp.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

reghdfe snd_pass ecdis_see2 ecdis_see ecdis see see2 sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if snd_pass_o != . & snd_pass_e != ., absorb(dep_id) cluster(id)
outreg2 using "comp.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//*** DiD with a differential outcome
reghdfe snd_pass_diff i.see_cat sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr, absorb(dep_id) cluster(id)
outreg2 using "diff.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

reghdfe snd_pass_diff see see2 sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr, absorb(dep_id) cluster(id)
outreg2 using "diff.xls", alpha(0.01, 0.05, 0.1) symbol(***, **, *) dec(4)

//******* did_multiplegt
display "$S_TIME"
did_multiplegt snd_pass_diff dep_id cyr see, placebo(3) controls(sex_rc2 indig star admq_rc5 pexam_rc5) threshold_stable_treatment(25)cluster(id)
display "$S_TIME"

//******* treatment effect differences by university types *******//
//*** ordinary / top
forvalues i = 0/1 {
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1 & top_uni == `i', absorb(dep_id) cluster(id)

outreg2 using "ord_top.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)
}

//*** private / public
forvalues i = 0/1 {
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1 & public == `i', absorb(dep_id) cluster(id)

outreg2 using "pri_pub.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)
}

//******* treatment effect differences by fields *******//
forvalues i = 0/1 {
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1 & stem == `i', absorb(dep_id) cluster(id)
outreg2 using "stem.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)
}

forvalues i = 1/11 {
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1 & bfd_id == `i', absorb(dep_id) cluster(id)
outreg2 using "bfd.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)
}

forvalues i = 1/27 {
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1 & nfd_id == `i', absorb(dep_id) cluster(id)
outreg2 using "nfd.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)
}

forvalues i = 1/11 {
reghdfe snd_pass c.see##ecdis c.see2##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1 & bfd_id == `i', absorb(dep_id) cluster(id)
outreg2 using "bfd_2.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(7)
}

forvalues i = 1/27 {
reg snd_pass c.see##ecdis c.see2##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr i.dep_id if up == 0 & fst_pass == 1 & uniq == 1 & nfd_id == `i', cluster(id)
outreg2 using "nfd_2.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(7)
}

//******* potential mechanisms
merge m:1 cyr depcd using "data\ecdis_plus.dta", force
drop _merge

//***** noted with perefential admission policies towards economically disadvantaged applicants
//*** categorical variables
reghdfe snd_pass see_cat##econ_adm##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "ecdis_plus_see_cat.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)

reghdfe snd_pass see_cat##ecdis econ_adm##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "ecdis_plus_see_cat.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)

//*** quadratic variables
reghdfe snd_pass c.see##econ_adm##ecdis c.see2##econ_adm##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "ecdis_plus_see_cont.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(7)

reghdfe snd_pass c.see##ecdis c.see2##ecdis econ_adm##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1, absorb(dep_id) cluster(id)
outreg2 using "ecdis_plus_see_cont.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(7)

//*** separate as groups
forvalues i = 0/1 {
reghdfe snd_pass see_cat##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1 & econ_adm == `i', absorb(dep_id) cluster(id)
outreg2 using "ecdis_plus_see_cat_group.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(4)
}

forvalues i = 0/1 {
reghdfe snd_pass c.see##ecdis c.see2##ecdis sex_rc2 indig star admq_rc5 pexam_rc5 i.cyr if up == 0 & fst_pass == 1 & uniq == 1 & econ_adm == `i', absorb(dep_id) cluster(id)
outreg2 using "ecdis_plus_see_cont_group.xls", alpha(0.01, 0.05, 0.1) symbol(***,**,*) dec(7)
}

//******* graph *******//
collapse (mean) see (firstnm) app_udep_rc2 latest_moecd_scd2_filled, by(cyr dep_id)

//*** generate codes for broad fields, fields and detailed fields 
//broad field
gen b_fd = usubstr(latest_moecd_scd2_filled, 6, 2)
egen bfd_id = group(b_fd)

//narrow field
gen n_fd = usubstr(latest_moecd_scd2_filled, 6, 3)
egen nfd_id = group(n_fd)

//detailed field
gen d_fd = usubstr(latest_moecd_scd2_filled, 6, 4)
egen dfd_id = group(d_fd)

save "p_see_dep_update.dta", replace

use "p_see_dep_update.dta", replace
preserve
collapse (mean) see (firstnm) b_fd, by(cyr bfd_id)
forvalues i = 1/11 {
	gen see_bfd_id`i' = see if bfd_id == `i'
}
collapse (mean) see_bfd_id1 - see_bfd_id11, by(cyr)

label variable see_bfd_id1 "Education"
label variable see_bfd_id2 "Arts and Humanities"
label variable see_bfd_id3 "Social Sciences, Journalism and Information"
label variable see_bfd_id4 "Business, Administration and Law"
label variable see_bfd_id5 "Natural Sciences, Mathematics and Statistics"
label variable see_bfd_id6 "Information and Communication Technologies"
label variable see_bfd_id7 "Engineering, Manufacturing and Construction"
label variable see_bfd_id8 "Agriculture, Forestry, Fisheries and Veterinary"
label variable see_bfd_id9 "Health and Welfare"
label variable see_bfd_id10 "Services"
label variable see_bfd_id11 "Others"

graph twoway (connected see_bfd_id1 - see_bfd_id11 cyr), ytitle("Non-blind Tests Percentage (%)", margin(l = 0 r = 1)) xtitle("Year", margin(t = 1)) legend(cols(3) rows(4) symy(tiny) symx(tiny) size(tiny))

graph export non_blind_cyr_bfd.png, replace
restore
