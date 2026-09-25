function write_flutter(obj,flutFile)
    fid = fopen(flutFile,"w");
    mni.printing.bdf.writeFileStamp(fid)
    mni.printing.bdf.writeComment(fid,'This file contain the flutter cards for a 145 solution')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');

    % define frequency / modes of interest
    mni.printing.bdf.writeComment(fid,'Frequencies and Modes of Interest')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    ads.nast.writeParams(fid,ads.nast.modeParamDefaults(obj.LModes,obj.FreqRange),obj.Params);

    %% define Modal damping
    mni.printing.bdf.writeComment(fid,'Modal Damping')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    if ~isempty(obj.DampingFreqs)
        dampFreqs = obj.DampingFreqs;
    elseif ~isempty(obj.FreqRange)
        dampFreqs = obj.FreqRange;
    else
        dampFreqs = [0,1]; % constant damping, any frequency range
    end
    dampVals = ones(1,numel(dampFreqs)).*obj.ModalDampingPercentage(:)';
    mni.printing.cards.TABDMP1(obj.SDAMP_ID,obj.DampingType,dampFreqs,dampVals).writeToFile(fid);
    
%     % Aero Properties Section
%     mni.printing.bdf.writeComment(fid,'Aerodynamic Properties')
%     mni.printing.bdf.writeColumnDelimiter(fid,'8');
%     %create AERO card
%     mni.printing.cards.AERO(obj.RefChord,obj.RefDensity,ACSID=obj.ACSID).writeToFile(fid);
    
    mni.printing.bdf.writeComment(fid,'Flutter Card and Properties')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    %create FLFACT cards
    fl_cards = [{mni.printing.cards.FLFACT(obj.Flfact_rho_id,...
        obj.rho/obj.RefDensity)},...
        {mni.printing.cards.FLFACT(obj.Flfact_mach_id,obj.Mach)},...
        {mni.printing.cards.FLFACT(obj.Flfact_v_id,obj.V)}]; 
    for i = 1:length(fl_cards)
        fl_cards{i}.writeToFile(fid)
    end

    %create flutter entry
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    f_card = mni.printing.cards.FLUTTER(obj.FlutterID,...
        obj.FlutterMethod,obj.Flfact_rho_id,...
        obj.Flfact_mach_id,obj.Flfact_v_id,[]);
    f_card.writeToFile(fid);
    if isempty(obj.ReducedMachs)
        Ms = unique(obj.Mach);
        if length(Ms)>5
            Ms = linspace(Ms(1),Ms(end),5);
        end
    else
        Ms = obj.ReducedMachs;
    end
    mni.printing.cards.MKAERO1(Ms,obj.ReducedFreqs).writeToFile(fid);
    fclose(fid);
end
function println(fid,string)
fprintf(fid,'%s\n',string);
end
