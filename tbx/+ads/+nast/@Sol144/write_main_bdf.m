function write_main_bdf(obj,filename,includes,opts)
arguments
    obj
    filename string
    includes (:,1) string
    opts.trimObjs = [];
end
    fid = fopen(filename,"w");
    mni.printing.bdf.writeFileStamp(fid)
    %% Case Control Section
    mni.printing.bdf.writeComment(fid,'This file contain the main cards + case control for a 144 solution')
    mni.printing.bdf.writeHeading(fid,'Case Control');
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    println(fid,'NASTRAN NLINES=999999');
    if obj.OutputAeroMatrices
        println(fid,'ASSIGN output4=''../bin/AJJ.op4'',formatted,UNIT=11');
        println(fid,'ASSIGN output4=''../bin/FFAJ.op4'',formatted,UNIT=12');
    end
    println(fid,'SOL 144');
    println(fid,'TIME 10000');
    if obj.OutputAeroMatrices
        println(fid,'COMPILE PFAERO $');
        % println(fid,'ALTER 275$'); % nastran 2018
        println(fid,'ALTER 277$'); % nastran 2021
        % println(fid,'ALTER ''AJJ''$'); % nastran 2022
        println(fid,'OUTPUT4 AJJ,,,,//0/11///8 $');
        println(fid,'COMPILE AESTATRS $');
        println(fid,'ALTER ''ASDR'' $');
        println(fid,'OUTPUT4 FFAJ,,,,//0/12///8 $');
    end
    println(fid,'CEND');
    mni.printing.bdf.writeHeading(fid,'Case Control')
    println(fid,'ECHO=NONE');
    println(fid,'VECTOR(SORT1,REAL)=ALL');
    println(fid,sprintf('TRIM = %.0f',obj.Trim_ID));
    println(fid,sprintf('METHOD = %.0f',obj.EigR_ID));
    fprintf(fid,'SPC=%.0f\n',obj.SPC_ID);
    fprintf(fid,'LOAD=%.0f\n',obj.Load_ID);
    println(fid,'MONITOR = ALL');
    println(fid,'SPCFORCES = ALL');
    println(fid,'FORCE(SORT1,REAL) = ALL');
    println(fid,'DISPLACEMENT(SORT1,REAL)=ALL');
    println(fid,'GROUNDCHECK=YES');
    println(fid,'AEROF=ALL');
    println(fid,'APRES=ALL');
    mni.printing.bdf.writeHeading(fid,'Begin Bulk')
    %% Bulk Data
    println(fid,'BEGIN BULK')
    % include files
    for i = 1:length(includes)
        mni.printing.cards.INCLUDE(includes(i)).writeToFile(fid);
    end
    %write Boundary Conditions
    mni.printing.bdf.writeComment(fid, 'SPCs')
    mni.printing.cards.SPCADD(obj.SPC_ID,obj.SPCs).writeToFile(fid);
    % write GRAV + loads
    mni.printing.bdf.writeComment(fid,'Gravity Card')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
%     mni.printing.cards.LOAD(obj.Load_ID,1,[obj.Grav_ID,obj.ForceIDs],[1,ones(size(obj.ForceIDs))]).writeToFile(fid);
    mni.printing.cards.LOAD(obj.Load_ID,1,obj.ForceIDs',ones(1,length(obj.ForceIDs))).writeToFile(fid);
    mni.printing.cards.GRAV(obj.Grav_ID,obj.g*obj.LoadFactor,obj.Grav_Vector)...
        .writeToFile(fid);
    % genric options 
    mni.printing.cards.PARAM('POST','i',0).writeToFile(fid);
    mni.printing.cards.PARAM('AUTOSPC','s','YES').writeToFile(fid);
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
    fclose(fid);
end
function println(fid,string)
fprintf(fid,'%s\n',string);
end
