function write_main_bdf(obj,filename,includes)
arguments
    obj
    filename string
    includes (:,1) string
end
    fid = fopen(filename,"w");
    mni.printing.bdf.writeFileStamp(fid)
    %% Case Control Section
    mni.printing.bdf.writeComment(fid,'This file contain the main cards + case control for a 145 solution')
    mni.printing.bdf.writeHeading(fid,'Case Control');
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    println(fid,'NASTRAN NLINES=999999');
    ads.nast.writeLines(fid,obj.FileManagement);
    println(fid,'SOL 145');
    println(fid,'TIME 10000');
    ads.nast.writeLines(fid,obj.ExecControl);
    println(fid,'CEND');
    mni.printing.bdf.writeHeading(fid,'Case Control')
    println(fid,'ECHO=NONE');
    println(fid,'VECTOR(SORT1,REAL)=ALL');
    println(fid,sprintf('SDAMP = %.0f',obj.SDAMP_ID));
    println(fid,sprintf('FMETHOD = %.0f',obj.FlutterID));
    println(fid,sprintf('METHOD = %.0f',obj.EigR_ID));
    if ~isempty(obj.SPCs)
        fprintf(fid,'SPC=%.0f\n',obj.SPC_ID);
    end

    if ~isempty(obj.K2GG)
        fprintf(fid,'K2GG=%s\n',obj.K2GG);
    end

    if ~isempty(obj.DispIDs)
        if any(isnan(obj.DispIDs))
            println(fid,'DISPLACEMENT(SORT1,REAL)= NONE');
        else
            mni.printing.cases.SET(1,obj.DispIDs).writeToFile(fid);
            println(fid,'DISPLACEMENT(SORT1,REAL)= 1');
        end
    else
        println(fid,'DISPLACEMENT(SORT1,REAL)= ALL');
    end
    if ~isempty(obj.ForceIDs)
        if any(isnan(obj.ForceIDs))
            println(fid,'FORCE(SORT1,REAL)= NONE');
        else
            mni.printing.cases.SET(2,obj.ForceIDs).writeToFile(fid);
            println(fid,'FORCE(SORT1,REAL)= 2');
        end
    else
        println(fid,'FORCE(SORT1,REAL)= ALL');
    end
    println(fid,'MONITOR = ALL');  

    println(fid,'GROUNDCHECK=YES');
    println(fid,'AEROF=ALL');
    println(fid,'APRES=ALL');

    % extra case control lines
    ads.nast.writeLines(fid,obj.ExtraCaseControl);

    mni.printing.bdf.writeHeading(fid,'Begin Bulk')
    %% Bulk Data
    println(fid,'BEGIN BULK')
    % include files
    for i = 1:length(includes)
        mni.printing.cards.INCLUDE(includes(i)).writeToFile(fid);
    end
    % generic options 
    params = ads.nast.writeParams(fid,{...
        'POST','i',0;...
        'AUTOSPC','s','YES';...
        'GRDPNT','i',0;...
        'BAILOUT','i',-1;...
        'OPPHIPA','i',1;...
        'AUNITS','r',0.1019716},obj.Params);
    mni.printing.cards.MDLPRM('HDF5','i',0).writeToFile(fid);

    if obj.setCoupledMass
        params = [params;ads.nast.writeParams(fid,{'COUPMASS','i',1},obj.Params)];
    end

    %write Boundary Conditions
    if ~isempty(obj.SPCs)
        mni.printing.bdf.writeComment(fid, 'SPCs')
        mni.printing.cards.SPCADD(obj.SPC_ID,obj.SPCs).writeToFile(fid);
    end
    
    %create eigen solver and frequency bounds
    mni.printing.bdf.writeComment(fid,'Eigen Decomposition Method')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');

    % mni.printing.cards.EIGR(obj.EigR_ID,'MGIV','F1',0,...
    %      'F2',obj.FreqRange(2),'NORM','MAX')...
    %      .writeToFile(fid);
    eig = ads.nast.eigCard(obj.EigR_ID,obj.EigMethod,obj.FreqRange,obj.EigND,obj.EigNorm);
    eig.writeToFile(fid);

    % PARAMs not written here or in the flutter file (write_flutter)
    modeParams = ads.nast.modeParamDefaults(obj.LModes,obj.FreqRange);
    params = [params;string(modeParams(:,1))];
    ads.nast.writeExtraParams(fid,obj.Params,params);
    fclose(fid);
end
function println(fid,string)
fprintf(fid,'%s\n',string);
end
