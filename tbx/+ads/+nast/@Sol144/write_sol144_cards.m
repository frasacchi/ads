function write_sol144_cards(obj,trimFile,trimObjs)
arguments
    obj
    trimFile string
    trimObjs = [];
end
    fid = fopen(trimFile,"w");
    mni.printing.bdf.writeFileStamp(fid)
    mni.printing.bdf.writeComment(fid,'This file contain the trim cards for a 144 solution')
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

    % create aestat cards
    mni.printing.bdf.writeComment(fid,'AESTAT Cards')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    param_names = fieldnames(obj);
    for i = 1:length(param_names)
        trim_obj = obj.(param_names{i});
        if isa(trim_obj,'ads.nast.TrimParameter')
            if strcmp(trim_obj.Type,'Rigid Body')
                mni.printing.cards.AESTAT(i,trim_obj.Name).writeToFile(fid);
            end
        end    
    end  

    % write aero constants
%     mni.printing.cards.AEROS(obj.RefChord,obj.RefSpan,obj.RefArea,ACSID=obj.ACSID).writeToFile(fid);

    % set trim values (NAN is free and will not be included in trim card)
    labels = [];
    mni.printing.bdf.writeComment(fid,'AELINK Cards')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    for i = 1:length(param_names)
        trim_obj = obj.(param_names{i});
        if isa(trim_obj,'ads.nast.TrimParameter')
            if ~isempty(trim_obj.Link)
                mni.printing.cards.AELINK(trim_obj.Name,{trim_obj.Link}).writeToFile(fid);
            elseif ~isnan(trim_obj.Value)
                labels = [labels,{trim_obj.Name},{trim_obj.Value}];
            end
        end    
    end
    for i = 1:length(trimObjs)
        trim_obj = trimObjs(i);
        if ~isempty(trim_obj.Link)
            mni.printing.cards.AELINK(trim_obj.Name,{trim_obj.Link}).writeToFile(fid);
        elseif ~isnan(trim_obj.Value)
            labels = [labels,{trim_obj.Name},{trim_obj.Value}];
        end
    end

    % write trim card
    mni.printing.bdf.writeComment(fid,'Trim Card')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    Q = 0.5*obj.rho*obj.V^2;
    t_card= mni.printing.cards.TRIM(obj.Trim_ID,obj.Mach,Q,...
        labels(:),'AEQR',obj.AEQR);    
    t_card.writeToFile(fid);
    fclose(fid);
end
function println(fid,string)
fprintf(fid,'%s\n',string);
end
