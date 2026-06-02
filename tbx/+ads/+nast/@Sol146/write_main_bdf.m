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
    mni.printing.bdf.writeComment(fid,'This file contain the main cards + case control for a 146 solution')
    mni.printing.bdf.writeHeading(fid,'Case Control');
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    println(fid,'NASTRAN BARMASS=1');
    println(fid,'NASTRAN NLINES=999999');
    println(fid,'NASTRAN QUARTICDLM=1');
    println(fid,'SOL 146');
    println(fid,'TIME 10000');
    println(fid,'CEND');
    println(fid,'ECHOOFF');
    println(fid,'ECHO=NONE');
    mni.printing.bdf.writeHeading(fid,'Case Control')
    fprintf(fid,'SPC=%.0f\n',obj.SPC_ID);
    println(fid,'RESVEC = YES');
    println(fid,'K2PP = STIFF');   
    println(fid,sprintf('SDAMP = %.0f',obj.SDAMP_ID));
    println(fid,sprintf('FREQ = %.0f',obj.FREQ_ID));
    println(fid,sprintf('TSTEP = %.0f',obj.TSTEP_ID));
    println(fid,sprintf('METHOD = %.0f',obj.EigR_ID));
    
    % println(fid,'VECTOR(SORT1,REAL)=ALL');
    
    % check if any of the gusts are turbulence cases
    turbCount = 0;
    for i = 1:length(obj.Gusts)
        turbCount = turbCount + isa(obj.Gusts(i), 'ads.nast.gust.Turb');
    end
    
    % if any gusts are turbulence cases then we'll want the Power Spectral Density Function (PSDF) in output.
    if turbCount > 0
        for i = 1:length(obj.Outputs)
            obj.Outputs(i).Args = unique([obj.Outputs(i).Args,"PSDF"]);
        end
    end

    obj.Outputs.WriteToFile(fid);
    obj.writeGroundCheck(fid);
    
    println(fid,'MONITOR = ALL');    
    
    % write gust subcases
    for i = 1:length(obj.Gusts)
        obj.Gusts(i).write_subcase(fid,i);
    end

    %% Bulk Data
    mni.printing.bdf.writeHeading(fid,'Begin Bulk')
    println(fid,'BEGIN BULK');
    
    % include files
    for i = 1:length(includes)
        mni.printing.cards.INCLUDE(includes(i)).writeToFile(fid);
    end
    % genric options 
    mni.printing.cards.PARAM('POST','i',0).writeToFile(fid);
    mni.printing.cards.PARAM('AUTOSPC','s','YES').writeToFile(fid);
    mni.printing.cards.PARAM('GRDPNT','i',0).writeToFile(fid);
    mni.printing.cards.PARAM('BAILOUT','i',-1).writeToFile(fid);
    % mni.printing.cards.PARAM('OPPHIPA','i',1).writeToFile(fid);
    mni.printing.cards.PARAM('AUNITS','r',0.1019716).writeToFile(fid);
    mni.printing.cards.PARAM('GUSTAERO','i',-1).writeToFile(fid);
    mni.printing.cards.MDLPRM('HDF5','i',0).writeToFile(fid);

    %write Boundary Conditions
    mni.printing.bdf.writeComment(fid, 'SPCs')
    mni.printing.cards.SPCADD(obj.SPC_ID,obj.SPCs).writeToFile(fid);
       
    %create eigen solver and frequency bounds
    mni.printing.bdf.writeComment(fid,'Eigen Decomposition Method')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    mni.printing.cards.EIGR(obj.EigR_ID,'MGIV','F1',0,...
         'F2',obj.FreqRange(2),'NORM','MAX')...
         .writeToFile(fid);
%     mni.printing.cards.EIGR(10,'MGIV','ND',42,'NORM','MAX')...
%         .writeToFile(fid);

    % write gust specific cards
    obj.write_gust(fid);
    println(fid,'ENDDATA')
    fclose(fid);
end
