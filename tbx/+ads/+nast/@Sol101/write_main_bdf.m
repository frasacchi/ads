function write_main_bdf(obj,filename,includes)
arguments
    obj
    filename
    includes (:,1) string
end
fid = fopen(filename,"w");
mni.printing.bdf.writeFileStamp(fid)
%% Case Control Section
mni.printing.bdf.writeComment(fid,'This file contain the main cards + case control for a 101 solution')
mni.printing.bdf.writeHeading(fid,'Case Control');
mni.printing.bdf.writeColumnDelimiter(fid,'8');
println(fid,'NASTRAN NLINES=999999');
println(fid,'SOL 101');

println(fid,'CEND');
mni.printing.bdf.writeHeading(fid,'Case Control')
println(fid,'ECHO=NONE');
println(fid,'VECTOR(SORT1,REAL)=ALL');
fprintf(fid,'SPC=%.0f\n',obj.SPC_ID);
fprintf(fid,'LOAD=%.0f\n',obj.Load_ID);
println(fid,'DISPLACEMENT(SORT1,REAL)=ALL');
println(fid,'FORCE(SORT1,REAL)=ALL');
println(fid,'GROUNDCHECK=YES');
% extra case control lines
if ~isempty(obj.ExtraCaseControl)
    for i = 1:length(obj.ExtraCaseControl)
        println(fid,obj.ExtraCaseControl(i));
    end
end
mni.printing.bdf.writeHeading(fid,'Begin Bulk')
%% Bulk Data
println(fid,'BEGIN BULK')
% include files
for i = 1:length(includes)
    mni.printing.cards.INCLUDE(includes(i)).writeToFile(fid);
end
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
%extra cards
if ~isempty(obj.ExtraCards)
    mni.printing.bdf.writeComment(fid,'Extra Cards')
end
for i = 1:length(obj.ExtraCards)
    obj.ExtraCards(i).writeToFile(fid);
end

%write Boundary Conditions
mni.printing.bdf.writeComment(fid, 'SPCs')
mni.printing.cards.SPCADD(obj.SPC_ID,obj.SPCs).writeToFile(fid);
%Write Main Load Card
%write gravity card
mni.printing.bdf.writeComment(fid,'Gravity Card')
mni.printing.bdf.writeColumnDelimiter(fid,'8');
mni.printing.cards.LOAD(obj.Load_ID,1,[obj.Grav_ID,obj.ForceIDs],[1,ones(size(obj.ForceIDs))]).writeToFile(fid);
mni.printing.cards.GRAV(obj.Grav_ID,obj.g*obj.LoadFactor,obj.Grav_Vector)...
    .writeToFile(fid);
fclose(fid);
end
function println(fid,string)
fprintf(fid,'%s\n',string);
end
