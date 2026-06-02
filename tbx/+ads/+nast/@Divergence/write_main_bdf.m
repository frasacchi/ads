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
    mni.printing.bdf.writeComment(fid,'This file contain the main cards + case control for a 144 divergence solution')
    mni.printing.bdf.writeHeading(fid,'Executive Control');
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    println(fid,'NASTRAN NLINES=999999');
    println(fid,'SOL 144');
    println(fid,'TIME 10000');
    println(fid,'CEND');
    println(fid,'ECHOOFF');
    println(fid,'ECHO=NONE');
    mni.printing.bdf.writeHeading(fid,'Case Control')
    fprintf(fid,'SPC=%.0f\n',obj.SPC_ID);
    println(fid,'AEROF=ALL');
    println(fid,'APRES=ALL');
    fprintf(fid,'DIVERG=%.0f\n',obj.Div_ID);
    fprintf(fid,'CMETHOD=%.0f\n',obj.Div_ID);
    obj.Outputs.WriteToFile(fid);
    obj.writeGroundCheck(fid);

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

    % genric options 
    mni.printing.cards.PARAM('POST','i',0).writeToFile(fid);
    mni.printing.cards.PARAM('AUTOSPC','s','YES').writeToFile(fid);
    mni.printing.cards.PARAM('GRDPNT','i',0).writeToFile(fid);
    mni.printing.cards.PARAM('BAILOUT','i',-1).writeToFile(fid);
    mni.printing.cards.PARAM('OPPHIPA','i',1).writeToFile(fid);
    mni.printing.cards.PARAM('AUNITS','r',0.1019716).writeToFile(fid);
    mni.printing.cards.MDLPRM('HDF5','i',0).writeToFile(fid);

    % mni.printing.cards.PARAM('FKSYMFAC','r',0).writeToFile(fid);

    % write divergence related cards
    mni.printing.bdf.writeComment(fid,'Divergence Cards')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    mni.printing.cards.DIVERG(obj.Div_ID,obj.N_Roots,obj.Mach).writeToFile(fid);
    mni.printing.cards.EIGC(obj.Div_ID,obj.eig_meth,obj.N_Roots).writeToFile(fid);
    println(fid,'ENDDATA')
    fclose(fid);

end
