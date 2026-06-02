function write_main_bdf(obj,filename,includes,feModel)
arguments
    obj
    filename string
    includes (:,1) string
    feModel ads.fe.Component
end
fid = fopen(filename,"w");
println(fid,'ECHOOFF');
mni.printing.bdf.writeFileStamp(fid)
%% Case Control Section
mni.printing.bdf.writeComment(fid,'This file contain the main cards + case control for a 103 solution')
mni.printing.bdf.writeHeading(fid,'Case Control');
mni.printing.bdf.writeColumnDelimiter(fid,'8');
println(fid,'NASTRAN NLINES=999999');
println(fid,'SOL 103');
println(fid,'CEND');
println(fid,'ECHOOFF');
println(fid,'ECHO=NONE');
mni.printing.bdf.writeHeading(fid,'Case Control')

fprintf(fid,'METHOD=%.0f\n',obj.EigR_ID);
fprintf(fid,'SPC=%.0f\n',obj.SPC_ID);

obj.Outputs.WriteToFile(fid);
obj.writeGroundCheck(fid);

mni.printing.bdf.writeHeading(fid,'Begin Bulk')
%% Bulk Data
println(fid,'BEGIN BULK')
% include files
for i = 1:length(includes)
    mni.printing.cards.INCLUDE(includes(i)).writeToFile(fid);
end
% genric options
mni.printing.cards.PARAM('WTMASS','r',1).writeToFile(fid);
mni.printing.cards.PARAM('SNORM','r',20).writeToFile(fid);
mni.printing.cards.PARAM('AUTOSPC','s','YES').writeToFile(fid);
mni.printing.cards.PARAM('PRTMAXIM','s','YES').writeToFile(fid);
mni.printing.cards.PARAM('GRDPNT','i',0).writeToFile(fid);
mni.printing.cards.PARAM('BAILOUT','i',-1).writeToFile(fid);
mni.printing.cards.PARAM('OPPHIPA','i',1).writeToFile(fid);
mni.printing.cards.PARAM('AUNITS','r',0.1019716).writeToFile(fid);
mni.printing.cards.MDLPRM('HDF5','i',0).writeToFile(fid);

%write Boundary Conditions
mni.printing.bdf.writeComment(fid, 'SPCs')
mni.printing.cards.SPCADD(obj.SPC_ID,obj.SPCs).writeToFile(fid);

%create eigen solver and frequency bounds
mni.printing.bdf.writeComment(fid,'Eigen Decomposition Method')
mni.printing.bdf.writeColumnDelimiter(fid,'8');
mni.printing.cards.EIGR(obj.EigR_ID,'AGIV','F1',0,...
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
println(fid,'ENDDATA')
fclose(fid);
end
