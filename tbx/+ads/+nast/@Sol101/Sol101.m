classdef Sol101 < ads.nast.BaseSol
    %SOL101 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % generic aero parameters
        Name = 'sol101';

        SPC_ID = 1;
        Grav_ID = 2;
        Load_ID = 3;

        % CoM Info for Boundary Constraints
        ExtraCards = mni.printing.cards.BaseCard.empty;
        ExtraCaseControl = [];
        setCoupledMass = false;

        K2GG = [];

    end
    
    methods
        function ids = UpdateID(obj,ids)
                obj.SPC_ID = ids.SID;
                obj.Grav_ID = ids.SID + 1;
                obj.Load_ID = ids.SID + 2;
                ids.SID = ids.SID + 3;
                ids.EID = ids.EID + 1;                
        end
    end
end

