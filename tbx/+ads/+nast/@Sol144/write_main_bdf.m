function write_main_bdf(obj,filename,includes,opts)
arguments
    obj
    filename string
    includes (:,1) string
    opts.trimObjs = [];
end
    fid = fopen(filename,"w");
    %% Case Control Section
    %new lines
    % println(fid,'NASTRAN MEM=16GB');
    % println(fid,'NASTRAN PARALLEL=1');

    mni.printing.bdf.writeFileStamp(fid)
    mni.printing.bdf.writeComment(fid,'This file contain the main cards + case control for a 144 solution')
    mni.printing.bdf.writeHeading(fid,'Case Control');
    mni.printing.bdf.writeColumnDelimiter(fid,'8');

    println(fid,'NASTRAN NLINES=999999');
    ads.nast.writeLines(fid,obj.FileManagement);
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
    ads.nast.writeLines(fid,obj.ExecControl);
    println(fid,'CEND');
    mni.printing.bdf.writeHeading(fid,'Case Control')
    println(fid,'ECHO=NONE');
    println(fid,'VECTOR(SORT1,REAL)=ALL');
    println(fid,sprintf('TRIM = %.0f',obj.Trim_ID));
    println(fid,sprintf('METHOD = %.0f',obj.EigR_ID));
    if ~isempty(obj.SPCs)
        fprintf(fid,'SPC=%.0f\n',obj.SPC_ID);
    end

    if ~isempty(obj.K2GG)
        fprintf(fid,'K2GG=%s\n',obj.K2GG);
    end

    % if obj.isFree
    % fprintf(fid,'SUPORT1=%.0f\n',obj.SUPORT1_ID);
    % end

    fprintf(fid,'LOAD=%.0f\n',obj.Load_ID);
    println(fid,'MONITOR = ALL');
    println(fid,'SPCFORCES = ALL');
    println(fid,'FORCE(SORT1,REAL) = ALL');         % EDW - leave this as is: sol144.run seems to have some additional functionality which utilises the forceIDs object in a different way to sol146 
    println(fid,'DISPLACEMENT(SORT1,REAL)=ALL');    % EDW - Again, leave this alone.

    % request stresses
    if ~isempty(obj.StressIDs)
        if any(isnan(obj.StressIDs))
            println(fid,'STRESS(SORT1,REAL)= NONE');
        else
            mni.printing.cases.SET(3,obj.StressIDs).writeToFile(fid);
            println(fid,'STRESS(SORT1,REAL)= 3');
        end
    else
        println(fid,'STRESS(SORT1,REAL)= ALL');
    end
    
    println(fid,'GROUNDCHECK=YES');
    println(fid,'AEROF=ALL');
    println(fid,'APRES=ALL');
    ads.nast.writeLines(fid,obj.ExtraCaseControl);
    mni.printing.bdf.writeHeading(fid,'Begin Bulk')
    %% Bulk Data
    println(fid,'BEGIN BULK')
    % include files
    for i = 1:length(includes)
        mni.printing.cards.INCLUDE(includes(i)).writeToFile(fid);
    end
    %write Boundary Conditions
    if ~isempty(obj.SPCs)
        mni.printing.bdf.writeComment(fid, 'SPCs')
        mni.printing.cards.SPCADD(obj.SPC_ID,obj.SPCs).writeToFile(fid);
    end
    % write GRAV + loads
    mni.printing.bdf.writeComment(fid,'Gravity Card')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    mni.printing.cards.LOAD(obj.Load_ID,1,[obj.Grav_ID;obj.ForceIDs(:)],[1;ones(numel(obj.ForceIDs),1)]).writeToFile(fid);
    % mni.printing.cards.LOAD(obj.Load_ID,1,obj.ForceIDs',ones(1,length(obj.ForceIDs))).writeToFile(fid);
    mni.printing.cards.GRAV(obj.Grav_ID,obj.g*obj.LoadFactor,obj.Grav_Vector)...
        .writeToFile(fid);
    % genric options 
    params = ads.nast.writeParams(fid,{...
        'POST','i',0;...
        'AUTOSPC','s','YES';...
        'GRDPNT','i',0;...
        'BAILOUT','i',-1;...
        'OPPHIPA','i',1;...
        'AUNITS','r',0.1019716},obj.Params);
    mni.printing.cards.MDLPRM('HDF5','i',0).writeToFile(fid);
    
    %create eigen solver and frequency bounds
    mni.printing.bdf.writeComment(fid,'Eigen Decomposition Method')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    eig = ads.nast.eigCard(obj.EigR_ID,obj.EigMethod,obj.FreqRange,obj.EigND,obj.EigNorm);
    eig.writeToFile(fid);
%     mni.printing.cards.EIGR(10,'MGIV','ND',42,'NORM','MAX')...
%         .writeToFile(fid);

    % PARAMs not written here or in the trim file (write_sol144_cards)
    modeParams = ads.nast.modeParamDefaults(obj.LModes,obj.FreqRange);
    ads.nast.writeExtraParams(fid,obj.Params,[params;string(modeParams(:,1))]);
    fclose(fid);
end
function println(fid,string)
fprintf(fid,'%s\n',string);
end
