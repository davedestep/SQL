libname david "";
%macro multiselect(file=, tables=demographics, dataname=all_eligible, eligible="yes", HIV_pos="no", NYS="no", reporttitle="Fall 2018", strat=); /*, missing=yes*/
OPTIONS SPOOL  NOMLOGIC NOMPRINT NOMRECALL NOSYMBOLGEN;
/*More efficient to use: NOMLOGIC, NOMPRINT, NOMRECALL, and NOSYMBOLGEN.*/


%do i = 1 %to &number_of_vars; 
%let question = %scan(&vargroup, &i);


data &dataname.;
length &question $50;
set &file.;
eligible = &eligible.;
if eligible="yes" then do;
if elgby = "Eligible" or elgby=1;
end;
HIV_Pos = &HIV_pos.;
if HIV_Pos="no" then do;
if t_status = "Positive" or n_test_result=1 THEN DELETE;
end;
NYS = &NYS.;
if NYS="no" then NYS=NYS;
else if NYSCriteria = "PrEP Eligible";
if missing(&question.) then &question.="missing";
run;


proc sql;
	create table &tables.&i as /*Could potentially make this &question. or &question&i, but I am afraid it would be less readable*/ 
	select 
	&question. as &question. Label="&question.,...", 
	count(&question.) as count_&question. Label="Fall 2017 (n=&)" ,
	(Count(&question.) / (Select Count(&question.) From &dataname. where &question. ne "missing")) as percent Label="Percent" format percent8.2
from &dataname.
where &question. ne "missing"
group by &question.

UNION ALL

select 'Subtotal Non Missing' as &question., count(&question.),
1 format percent8.2 as percent
from &dataname.
where &question. ne "missing"

UNION ALL

select 
	&question., count(&question.),
	(Count(&question.)/ (Select Count(&question.) From &dataname.)) as percent format percent8.2
from &dataname.
where &question. = "missing"
group by &question.;
quit;

/*Code Chunk1*/
/*CREATE STRATIFICATIONS */
/*************************************************************************************************************************/
proc sql;
create table test as
select distinct(&strat.) as response_names
from &dataname.;
%let n=&sqlobs;
quit;

proc sql noprint;
select response_names into :name1-:name&n.
from test;
quit;

%do j=1 %to &n.;
proc sql;
create table online&i.&j. as
select 
&question. as &question. Label="&question,...", 
	count(&question.) as count_&question.&j. Label="n &name&j" ,
	(Count(&question.) / (Select Count(&question.) From all_eligible where &question. ne "missing" and &strat.="&name&j")) as percent&j. Label="Percent &name&j" format percent8.2
from all_eligible
where &question. ne "missing" and &strat.="&name&j"  /**!! and &strat=responses!!**/
group by &question.


/*Code Chunk 2 Adding totals to Strata Tables*/
/*******************************************/
UNION ALL

select 'Subtotal Non Missing' as &question., count(&question.),
1 format percent8.2 as percent
from &dataname.
where &question. ne "missing" and &strat.="&name&j"

UNION ALL

select 
	&question., count(&question.),
	(Count(&question.)/ (Select Count(&question.) From &dataname. where &strat.="&name&j")) as percent format percent8.2
from &dataname.
where &question. = "missing" and &strat.="&name&j"
group by &question.;
quit;

/*Join the stratified tables to the overall/composite table*/
/*************************/
proc sql; 
create table &tables.&i. as 
select a.*, b.*
from work.&tables.&i. as a
left join Online&i.&j. as b
on a.&question. = b.&question.;
quit;

%end;
%end;

/****************************/
/*Output Report*/
ods listing close;
ods csv file="......summary.csv" style=MINIMAL  options(embedded_titles='on'     sheet_interval='none'     sheet_name="FOR_SUMMARY");
Title &reporttitle;
%do i = 1 %to &number_of_vars;
proc print data=&tables.&i. LABEL;
run;
%end;
ods csv close;
ods listing;
%mend;


/*So nothing has to be changed in the main macro, all changes occur here*/
%MACRO MULTISELECT2();
%let number_of_vars=6;
%let vargroup = 
question1
question2
question3 
question4
question10
question45/*etc*/
;
%multiselect(file=david.final, NYS="something else", strat=survformat);/*(file=, tables=demographics, dataname=all_eligible, eligible="yes", HIV_pos="no", NYS="no" reporttitle="Fall 2018", strat=)*/
%MEND;
%MULTISELECT2
