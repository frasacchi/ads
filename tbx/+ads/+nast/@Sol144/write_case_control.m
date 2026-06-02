function write_case_control(obj,fid)
    mni.printing.bdf.writeHeading(fid,'Executive Control');
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    println(fid,'NASTRAN NLINES=999999');
    println(fid,'ECHO=NONE');
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


    obj.Outputs.WriteToFile(fid);
    obj.writeGroundCheck(fid);

    println(fid,'AEROF=ALL');
    println(fid,'APRES=ALL');
end