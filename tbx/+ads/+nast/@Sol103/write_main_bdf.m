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
ads.nast.writeLines(fid,obj.FileManagement);
println(fid,'SOL 103');
ads.nast.writeLines(fid,obj.ExecControl);
println(fid,'CEND');
mni.printing.bdf.writeHeading(fid,'Case Control')
println(fid,'ECHO=NONE');

fprintf(fid,'METHOD=%.0f\n',obj.EigR_ID);
if ~isempty(obj.SPCs)
    fprintf(fid,'SPC=%.0f\n',obj.SPC_ID);
end
if obj.PunchDisplacements
    dispArgs = ',PUNCH';
else
    dispArgs = '';
end
if obj.WriteToF06
    println(fid,['DISPLACEMENT(SORT1,REAL',dispArgs,')=ALL']);
    println(fid,'FORCE(SORT1,REAL)=ALL');
    println(fid,['VECTOR(SORT1,REAL',dispArgs,')=ALL']);
    println(fid,'GROUNDCHECK=YES');
else
    println(fid,['DISPLACEMENT(SORT1,REAL,PLOT',dispArgs,')=ALL']);
    println(fid,'FORCE(SORT1,REAL,PLOT)=ALL');
    println(fid,['VECTOR(SORT1,REAL,PLOT',dispArgs,')=ALL']);
    println(fid,'GROUNDCHECK=NO');
end
ads.nast.writeLines(fid,obj.ExtraCaseControl);

% println(fid,'GROUNDCHECK=YES');
mni.printing.bdf.writeHeading(fid,'Begin Bulk')
%% Bulk Data
println(fid,'BEGIN BULK')
% include files
for i = 1:length(includes)
    mni.printing.cards.INCLUDE(includes(i)).writeToFile(fid);
end
% genric options
params = ads.nast.writeParams(fid,{...
    'WTMASS','r',1;...
    'SNORM','r',20;...
    'AUTOSPC','s','YES';...
    'PRTMAXIM','s','YES';...
    'GRDPNT','i',0;...
    'BAILOUT','i',-1;...
    'OPPHIPA','i',1;...
    'AUNITS','r',0.1019716},obj.Params);
mni.printing.cards.MDLPRM('HDF5','i',0).writeToFile(fid);

%write Boundary Conditions
if ~isempty(obj.SPCs)
    mni.printing.bdf.writeComment(fid, 'SPCs')
    mni.printing.cards.SPCADD(obj.SPC_ID,obj.SPCs).writeToFile(fid);
end

%create eigen solver and frequency bounds
mni.printing.bdf.writeComment(fid,'Eigen Decomposition Method')
mni.printing.bdf.writeColumnDelimiter(fid,'8');
eig = ads.nast.eigCard(obj.EigR_ID,obj.EigMethod,obj.FreqRange,obj.EigND,obj.EigNorm);
eig.writeToFile(fid);
%     mni.printing.cards.EIGR(10,'MGIV','ND',42,'NORM','MAX')...
%         .writeToFile(fid);

% define frequency / modes of interest
mni.printing.bdf.writeComment(fid,'Frequencies and Modes of Interest')
mni.printing.bdf.writeColumnDelimiter(fid,'8');
modeParams = ads.nast.modeParamDefaults(obj.LModes,obj.FreqRange);
params = [params;ads.nast.writeParams(fid,modeParams,obj.Params);string(modeParams(:,1))];
ads.nast.writeExtraParams(fid,obj.Params,params);
fclose(fid);
end
function println(fid,string)
fprintf(fid,'%s\n',string);
end
