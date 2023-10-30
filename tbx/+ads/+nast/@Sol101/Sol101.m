classdef Sol101 < handle
    %FLUTTERSIM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % generic aero parameters
        Name = 'SOL101';

        % grav info
        LoadFactor = 1;
        g = 9.81;
        Grav_Vector = [0;0;1];

        SPC_ID = 1;
        Grav_ID = 2;
        Load_ID = 3;
        
        SPCs = [];
        ForceIDs = [];

        % CoM Info for Boundary Constraints
        isFree = false; % if is Free a Boundary condition will be applied to  the Centre of Mass
        CoM = ads.fe.Constraint.empty;
        DoFs = [];
    end
    
    methods
        function ids = UpdateID(obj,ids)
                obj.SPC_ID = ids.SID;
                obj.Grav_ID = ids.SID + 1;
                obj.Load_ID = ids.SID + 2;
                ids.SID = ids.SID + 3;
                ids.EID = ids.EID + 1;                
        end
        function str = config_string(obj)
            str = '';
        end
    end
end

