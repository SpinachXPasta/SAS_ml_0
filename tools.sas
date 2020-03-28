

/*Helpr macros for SAS*/

%macro Reg_searchReplace(df= , col=, newcol= , regex=);
	data &df;*dfine dataset;
		set &df;
			&newcol = &col;*newcolumn which will contain the new variables;
			array Chars[*] &newcol; 
			do i = 1 to dim(Chars); * traverse that column;
				retain re;
				re = prxparse(&regex); 
				Chars[i] =  prxchange(re, -1,Chars[i]); *replace occurance of regex;
				;		
			end;
			drop re i;*drop newly creatd temp columns;
	run;
	
%mend Reg_searchReplace; 




%macro getMissing(df=);

data missing;
		set &df;
			numMissing = 0;
			array cols1 _numeric_;
			do over cols1;
				numMissing = numMissing + cmiss(cols1);;
			end;
		
			array cols2 _character_;
			do over cols2;
				numMissing = numMissing + cmiss(cols2);;
			end;
	run;
	
	proc sql;
	title 'Rows with missing values'; 
	select * from missing where numMissing > 0;
	quit;

%mend getMissing;




%macro columnwiseMissing(df=);
title 'Column Wise Missing Report';
	proc format;
 		value $missfmt ' '='Missing' other='Not Missing';
 		value  missfmt  . ='Missing' other='Not Missing';
	run;
 
	proc freq data=&df; 
		format _CHAR_ $missfmt.; /* apply format for the duration of this PROC */
		tables _CHAR_ / missing missprint nocum nopercent;
		format _NUMERIC_ missfmt.;
		tables _NUMERIC_ / missing missprint nocum nopercent;
	run;
%mend;





/* *Useful;
	data want_num(keep=_NUMERIC_) want_char(keep=_CHARACTER_);
    	set train;
	run;
	*/

/*
	*Back up for the above function;
	data train;
		set train;
			Title_col = Name;
	run;
	
	
	data train;
		set train;
			array Chars[*] Title_col;
			do i = 1 to dim(Chars);
				retain re;
				re = prxparse('s/(.*, )|( .*)//'); 
				Chars[i] =  prxchange(re, -1,Chars[i]);
				;		
			end;
			drop re i;
	run;
			
	*/