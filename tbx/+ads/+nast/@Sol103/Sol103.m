classdef Sol103 < ads.nast.BaseSol
    %FLUTTERSIM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % generic aero parameters
        Name = 'sol103';

        % freqeuency & Structural Damping Info
        FreqRange = [0.01,50];
        NFreq = 500;
        LModes = 20;
        ModalDampingPercentage = 0;

        EigR_ID = 1;
        SPC_ID = 2;
    end
    
    methods
        function ids = UpdateID(obj,ids)
                obj.EigR_ID = ids.SID;
                obj.SPC_ID = ids.SID + 1;
                ids.SID = ids.SID + 2;
        end
    end

end

