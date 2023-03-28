function write_main_bdf(obj,filename,includes)
arguments
    obj
    filename string
    includes (:,1) string
end
fid = fopen(filename,"w");
mni.printing.bdf.writeFileStamp(fid)
%% Case Control Section
mni.printing.bdf.writeComment(fid,'This file contain the main cards + case control for a 103 solution')
mni.printing.bdf.writeHeading(fid,'Case Control');
mni.printing.bdf.writeColumnDelimiter(fid,'8');
println(fid,'NASTRAN NLINES=999999');
println(fid,'SOL 103');
println(fid,'CEND');
mni.printing.bdf.writeHeading(fid,'Case Control')
println(fid,'ECHO=NONE');
println(fid,'VECTOR(SORT1,REAL)=ALL');
fprintf(fid,'METHOD=%.0f\n',obj.EigR_ID);
fprintf(fid,'SPC=%.0f\n',obj.SPC_ID);
println(fid,'DISPLACEMENT(SORT1,REAL)=ALL');
println(fid,'FORCE(SORT1,REAL)=ALL');
println(fid,'GROUNDCHECK=YES');
mni.printing.bdf.writeHeading(fid,'Begin Bulk')
%% Bulk Data
println(fid,'BEGIN BULK')
% include files
for i = 1:length(includes)
    mni.printing.cards.INCLUDE(includes(i)).writeToFile(fid);
end
%write Boundary Conditions
obj.write_boundary_conditions(fid);
% genric options
mni.printing.cards.PARAM('POST','i',0).writeToFile(fid);
mni.printing.cards.PARAM('WTMASS','r',1).writeToFile(fid);
mni.printing.cards.PARAM('SNORM','r',20).writeToFile(fid);
mni.printing.cards.PARAM('AUTOSPC','s','YES').writeToFile(fid);
mni.printing.cards.PARAM('PRTMAXIM','s','YES').writeToFile(fid);
mni.printing.cards.PARAM('GRDPNT','i',0).writeToFile(fid);
mni.printing.cards.PARAM('BAILOUT','i',-1).writeToFile(fid);
mni.printing.cards.PARAM('OPPHIPA','i',1).writeToFile(fid);
mni.printing.cards.PARAM('AUNITS','r',0.1019716).writeToFile(fid);
mni.printing.cards.MDLPRM('HDF5','i',0).writeToFile(fid);

%create eigen solver and frequency bounds
mni.printing.bdf.writeComment(fid,'Eigen Decomposition Method')
mni.printing.bdf.writeColumnDelimiter(fid,'8');
mni.printing.cards.EIGR(obj.EigR_ID,'MGIV','F1',0,...
    'F2',obj.FreqRange(2),'NORM','MAX')...
    .writeToFile(fid);
%     mni.printing.cards.EIGR(10,'MGIV','ND',42,'NORM','MAX')...
%         .writeToFile(fid);

% define frequency / modes of interest
mni.printing.bdf.writeComment(fid,'Frequencies and Modes of Interest')
mni.printing.bdf.writeColumnDelimiter(fid,'8');
mni.printing.cards.PARAM('LMODES','i',obj.LModes).writeToFile(fid);
mni.printing.cards.PARAM('LMODESFL','i',obj.LModes).writeToFile(fid);
mni.printing.cards.PARAM('LFREQ','r',obj.FreqRange(1)).writeToFile(fid);
mni.printing.cards.PARAM('HFREQ','r',obj.FreqRange(2)).writeToFile(fid);
mni.printing.cards.PARAM('LFREQFL','r',obj.FreqRange(1)).writeToFile(fid);
mni.printing.cards.PARAM('HFREQFL','r',obj.FreqRange(2)).writeToFile(fid);
fclose(fid);
end
function println(fid,string)
fprintf(fid,'%s\n',string);
end
