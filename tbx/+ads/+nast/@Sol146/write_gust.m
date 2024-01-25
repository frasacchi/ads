function write_gust(obj,gustFile)
    fid = fopen(gustFile,"w");
    mni.printing.bdf.writeFileStamp(fid)
    mni.printing.bdf.writeComment(fid,'This file contain the gust cards for a 146 solution')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');

    % define frequency / modes of interest
    mni.printing.bdf.writeComment(fid,'Frequencies and Modes of Interest')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    mni.printing.cards.PARAM('LMODES','i',obj.LModes).writeToFile(fid);
    mni.printing.cards.PARAM('LMODESFL','i',obj.LModes).writeToFile(fid);
    mni.printing.cards.PARAM('LFREQ','r',obj.FreqRange(1)).writeToFile(fid);
    mni.printing.cards.PARAM('HFREQ','r',obj.FreqRange(2)).writeToFile(fid);
    mni.printing.cards.PARAM('LFREQFL','r',obj.FreqRange(1)).writeToFile(fid);
    mni.printing.cards.PARAM('HFREQFL','r',obj.FreqRange(2)).writeToFile(fid);
    
    %% define Modal damping
    mni.printing.bdf.writeComment(fid,'Modal Damping')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    if isempty(obj.GustFreq)
        mni.printing.cards.TABDMP1(obj.SDAMP_ID,'CRIT',obj.FreqRange,ones(1,2)*obj.ModalDampingPercentage).writeToFile(fid);
    else
        mni.printing.cards.TABDMP1(obj.SDAMP_ID,'CRIT',[obj.FreqRange(1),obj.GustFreq,obj.GustFreq,obj.FreqRange(2)],[ones(1,2)*obj.ModalDampingPercentage,0.5,0.5]).writeToFile(fid);
    end
    %% Aero Properties Section
    mni.printing.bdf.writeComment(fid,'Aerodynamic Properties')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');

    %create AERO card
    mni.printing.cards.PARAM('Q','r',0.5*obj.rho*obj.V.^2).writeToFile(fid);
    mni.printing.cards.PARAM('MACH','r',obj.Mach).writeToFile(fid);
    % mni.printing.cards.AERO(obj.RefChord,obj.rho,'VELOCITY',obj.V).writeToFile(fid);
    mni.printing.cards.MKAERO1(obj.Mach,obj.ReducedFreqs).writeToFile(fid);

    %% Gust Properties Section
    mni.printing.bdf.writeComment(fid,'Global Gust Properties')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');

    if isempty(obj.GustFreq)
        Df = obj.FreqRange(2) - obj.FreqRange(1);
    else
        Df = obj.GustFreq - obj.FreqRange(1);
    end

    mni.printing.cards.FREQ1(obj.FREQ_ID,obj.FreqRange(1),Df/(obj.NFreq-1),(obj.NFreq-1)).writeToFile(fid);
    mni.printing.cards.FREQ(obj.FREQ_ID,0.001).writeToFile(fid);
    mni.printing.cards.TSTEP(obj.TSTEP_ID,ceil(obj.GustDuration/obj.GustTstep),obj.GustTstep).writeToFile(fid);
    %DAREA for 1MC
    mni.printing.bdf.writeComment(fid,'DAREA Card for one-minus-cosine excitation')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    mni.printing.cards.DAREA(obj.DAREA_ID,obj.CoM.Point.ID,3,1).writeToFile(fid);
    %DAREA for Turbulence
    mni.printing.bdf.writeComment(fid,'Monitor Point for Random Turbulence')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    mni.printing.cards.DAREA(obj.DAREA_ID+1,obj.EPoint_ID,0,1).writeToFile(fid);
    mni.printing.cards.EPOINT(obj.EPoint_ID).writeToFile(fid);
    mni.printing.cards.DMIG('STIFF',6,1,obj.EPoint_ID,0,obj.EPoint_ID,0,1,nan,TOUT=0).writeToFile(fid);
    %% Gust Case Properties Section
    for i = 1:length(obj.Gusts)
        if isa(obj.Gusts(i),'ads.nast.gust.OneMC')
            obj.Gusts(i).write_bdf(fid,obj.DAREA_ID,obj.V,i,alt=obj.Alt,FreqRange=obj.FreqRange);  
        elseif isa(obj.Gusts(i),'ads.nast.gust.Turb')
            obj.Gusts(i).write_bdf(fid,obj.DAREA_ID+1,obj.V,i,alt=obj.Alt,FreqRange=obj.FreqRange);  
        end
    end
    fclose(fid);
end
function println(fid,string)
fprintf(fid,'%s\n',string);
end
