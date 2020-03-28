/*Attempt to recreate analysis performed by Megan Risdal */
/* https://www.kaggle.com/mrisdal/exploring-survival-on-the-titanic */

*import macros from tools;
%include '/home/sp16670/Titanic/Code/tools.sas';

/*example proc csv*/
proc import datafile = '/home/sp16670/Titanic/Data/train.csv' 
	out = train
	dbms=csv replace;
run;

proc import datafile = '/home/sp16670/Titanic/Data/test.csv' 
	out = test
	dbms=csv replace;
run;

proc import datafile = '/home/sp16670/Titanic/Data/gender_submission.csv' 
	out = submission
	dbms=csv replace;
run;

data full;
	set train test;
run;


*Analysis Begins;

	ods graphics / width=640px height=480px;
	
	proc print data = full(obs = 5);
		title 'Sample output of the Data';
	run;
	
	proc contents data=full;
		title 'Summary of training data';
	run;
	


	*2.Feature engineering;
	%Reg_searchReplace(df = full, col = Name, newcol = Title_col, regex = 's/(.*, )|( .*)//');
	
	*Contingency Table of Male and Female and their class;
	proc freq data = full;
	title 'Contingency Table of Male and Female and their Titles';
	tables Sex*Title_col / nopercent nocol norow;
	run;
	
	*replace unfrequent titles with rare;
	data full;
		set full;
			Title_col = translate(Title_col,'','.');
			Title_col = translate(Title_col,'',' '); *strip whitespace;
			re = prxparse('s/Mlle/Miss/');
			Title_col = prxchange(re, -1,Title_col);
			re = prxparse('s/Ms/Miss/');
			Title_col = prxchange(re, -1,Title_col);
			re = prxparse('s/Mme/Mrs/');
			Title_col = prxchange(re, -1,Title_col);
			array Chars{11} $ ('Dona', 'Lady', 'the Countess','Capt', 'Col', 'Don', 'Dr', 'Major', 'Rev', 'Sir', 'Jonkheer'); 
			do i = 1 to dim(Chars); * traverse that column;
				regex_1 = catx('','s/',Chars[i]);
				regex_1 = compress(catx('',regex_1, '/Rare/'));
				re = prxparse(regex_1); 
				Title_col =  prxchange(re, -1,Title_col); *replace occurance of regex;
				;		
			end;
			drop Chars1 Chars2 Chars3 Chars4 Chars5 Chars6 Chars7 Chars8 Chars9 Chars10 Chars11 regex_1 i re;
			
	run;
	
	proc freq data = full;
	title 'Contingency Table of Male and Female and their Titles - 2 after alteration';
	tables Sex*Title_col / nopercent nocol norow;
	run;
	
	
	*Analysis on Family Size;
	data full;
		set full;
			Fsize = SibSp + Parch + 1;
			FsizeD = 'Singleton';
			if Fsize > 1 and Fsize < 5 then FsizeD = 'samll';
			if Fsize > 4 then FsizeD = 'large';
		run;
	
	proc sgplot data = full;
		vbar Fsize / group= Survived groupdisplay = cluster;
	title 'Survival vs Family Size';
	run;
	
	ods graphics on;
	proc freq data=full;
	tables Survived*FsizeD / norow nofreq plots=MOSAIC; /* alias for MOSAICPLOT */
	title 'Mosaic Plot Fsize Desc. vs Survived';
	run;
	
	*Extract deck from cabin;
	data full;
		set full;
			Deck = substr(Cabin,1,1);
	run;
	
	
	*Handle missing values;
	title 'Info on missing values 1';
	proc sql;
		select Fare, Pclass from full
		where PassengerId = 62 or PassengerId =830;
	quit;
	
	proc sgplot data = full;
		vbox Fare / category=Embarked group=Pclass;  
		refline 80;
	title 'Fare vs Embarkment';
	run;
	
	data full; *Fill missing values with C as most likely;
		set full;
			if PassengerId = 62 then Embarked = 'C';
			if PassengerId = 830 then Embarked = 'C';
	run;
	
	*miss rep;
	*https://blogs.sas.com/content/iml/2011/09/19/count-the-number-of-missing-values-for-each-variable.html;
	title 'Column Wise Missing Report';
	proc format;
 		value $missfmt ' '='Missing' other='Not Missing';
 		value  missfmt  . ='Missing' other='Not Missing';
	run;
 
	proc freq data=full; 
		format _CHAR_ $missfmt.; /* apply format for the duration of this PROC */
		tables _CHAR_ / missing missprint nocum nopercent;
		format _NUMERIC_ missfmt.;
		tables _NUMERIC_ / missing missprint nocum nopercent;
	run;
	
	*Subset dataframe with columns that don't have too many missing values;
	data sub_full;
		set full;
			drop Cabin Deck Age Survived;
		run;
	%getMissing(df = sub_full);
	
	title 'Info on missing values 2';
	proc sql;
		select * from full
		where PassengerId = 1044;
	quit;
	
	
	*visualize;
	proc sql;
	create table sub_full as
	select * from full
	where Pclass = 3 and Embarked = 'S';
	quit;
	
	proc sgplot data = sub_full;
	title 'Density of Fare'; 
	histogram Fare;
	*refline 21 / axis = x;
	run;
	
	*impute values with median value;
	proc sql;
	update full
	set Fare = (select median(Fare) from sub_full) 
	where PassengerId = 1044;
	quit;
	run;
	*;
		
		
	title 'Imputation of Var Age';
	proc sql;
		select * from full
		where PassengerId = 1044;
	quit;
	

	*impute values using sampler;
	data backUp;
		set full;
	run;
	
	proc mi data= full nimpute=1 out=full seed=54321;
	class Embarked FsizeD Title_col Sex;
	monotone regression ;
	var Pclass Fsize Parch Embarked FsizeD Title_col Sex Age;
	run;
	
	data full;
		set full;
			Age = abs(age);
	run;
	*imputation ends;
	
	*subplot starts;
	ods layout gridded columns=2 ;
	ods graphics / width=8cm height=6cm;
	ods region;
	
	proc sgplot data = backUp;
	title 'Old distribution of Age';
	histogram Age;
	run;
	ods region;
	
	proc sgplot data = full;
	title 'Imputed Distribution of Age'; 
	histogram Age;
	run;
	ods layout end;
	ods graphics / width=640px height=480px;
	*end of suplot;

	
	*Further impuation;
	data sub_full;
		set full;
		if cmiss(of Survived) =0;
	run;
	proc sgpanel data = sub_full;
	title 'Age faceted by Survival & Sex';
	panelby Sex;
	histogram Age / group=Survived nbins= 30;
	run;
	
	data full;
		set full;
			Child = 'Child';
			if Age >= 18 then Child = 'Adult';
			Mother = 'Not Mother';
			*https://www.educba.com/sas-operators/;
			if Sex = 'female' and Parch > 0 and Age > 18 and Title_col ~= 'Miss' then Mother = 'Mother';
	run;
	
	data sub_full;
		set full;
		if cmiss(of Survived) =0;
	proc freq data = sub_full;
	title 'Contingency Table Child Var';
	tables Child*Survived / nopercent nocol norow;
	run;
	
	proc freq data = sub_full;
	title 'Contingency Table Mother Var';
	tables Mother*Survived / nopercent nocol norow;
	run;
	
	
	%columnwiseMissing(df = full);
	
	
	*Prepr for test-train;
	Data Train;
		set full;
			if PassengerId <= 891;
			keep Survived Pclass Sex Age SibSp Parch Fare Embarked Title_col FsizeD Child Mother;
		run;
	Data Test;
		set full;
			if PassengerId > 891;
			keep Pclass Sex Age SibSp Parch Fare Embarked Title_col FsizeD Child Mother;
		run;
	
	* Start Training;
	* https://www.lexjansen.com/wuss/2019/204_Final_Paper_PDF.pdf;
	proc hpforest data = Train maxtrees = 50 seed = 14561 trainfraction=0.85;
	input Pclass Sex Age SibSp Parch Fare Embarked Title_col FsizeD Child Mother;
	target Survived / level = BINARY;
	ods output FitStatistics = fit_at_runtime;
	ods output VariableImportance = Variable_Importance;
	ods output Baseline = Baseline;
	run;
	
	*subplot starts;
	ods layout gridded columns=2 ;
	ods graphics / width=12cm height=8cm;
	ods region;
	title "The Average Square Error";
	proc sgplot data = fit_at_runtime;
 	series x=NTrees y=PredAll/legendlabel='Train Error';
 	series x=NTrees y=PredOOB/legendlabel='OOB Error';
 	xaxis values=(0 to 50 by 1);
 	yaxis values=(0 to 0.3 by 0.05) label='Average Square Error';
	run;
	ods region;
	title "The Misclasification Error";
	proc sgplot data = fit_at_runtime;
 	series x=NTrees y=MiscAll/legendlabel='Train Misclassification Error';
 	series x=NTrees y=MiscOOB/legendlabel='OOB Misclassification Error';
 	xaxis values=(0 to 50 by 1);
 	yaxis values=(0 to 0.3 by 0.05) label='Misclassification Error';
	run;

	ods region;
	title "Feature Importance Gini";
	proc sgplot data = Variable_Importance;
	vbar Variable /response=Gini  groupdisplay = cluster categoryorder=respdesc;
	run;
	
	ods region;
	title "Feature Importance GiniOOB";
	proc sgplot data = Variable_Importance;
	vbar Variable /response=GiniOOB  groupdisplay = cluster categoryorder=respdesc;
	run;
	
	*Predicting on new data;
	*http://www.mwsug.org/proceedings/2016/AA/MWSUG-2016-AA20.pdf;
	*Fit Model for predcition;
	ods exclude all; 
	proc hpforest data = Train maxtrees= 500 trainfraction=0.85
					leafsize=1 alpha= 0.1 seed = 14561;
	input Pclass Sex Age SibSp Parch Fare Embarked Title_col FsizeD Child Mother;
	target Survived / level = BINARY;
	ods output FitStatistics = fit_at_runtime;
	save file = "/home/sp16670/Titanic/output/model_fit.bin"; 
	run;
	ods exclude none; 
	
	*subplot starts;
	ods region;
	title "The Average Square Error for final model";
	proc sgplot data = fit_at_runtime;
 	series x=NTrees y=PredAll/legendlabel='Train Error';
 	series x=NTrees y=PredOOB/legendlabel='OOB Error';
 	xaxis values=(0 to 500 by 50);
 	yaxis values=(0 to 0.3 by 0.05) label='Average Square Error';
	run;
	ods region;
	title "The Misclasification Error for final model";
	proc sgplot data = fit_at_runtime;
 	series x=NTrees y=MiscAll/legendlabel='Train Misclassification Error';
 	series x=NTrees y=MiscOOB/legendlabel='OOB Misclassification Error';
 	xaxis values=(0 to 500 by 50);
 	yaxis values=(0 to 0.3 by 0.05) label='Misclassification Error';
	run;
	ods layout end;
	ods graphics / width=640px height=480px;
	*End of viz;
	
	proc hp4score data=Test; *Predictions;
	score file= "/home/sp16670/Titanic/output/model_fit.bin"
	out=Predictions;
	run;
	
	data submission;
		merge submission Predictions;
	run;
	
	/* Also Works*;
	data submission;
		set submission; 
		set Predictions;
	run;
	*/
	
	
	data submission;
		set submission;
			Survived = I_Survived;
			keep PassengerId Survived;
	run;
	

	proc export data=submission
    outfile='/home/sp16670/Titanic/output/submission.csv'
    dbms=csv
    replace;
	run;
	
	
