classdef Divergence < handle
    %FLUTTERSIM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % generic aero parameters
        Name = 'SOL144';
        Mach = 0;

        N_Roots = 1;
        eig_meth char = 'CLAN';

        Div_ID = 1
        SPC_ID = 2;
        Load_ID = 4;

        SPCs = [];
        ForceIDs = [];

        % CoM Info for Boundary Constraints
        isFree = false; % if is Free a Boundary condition will be applied to  the Centre of Mass
        CoM = ads.fe.Constraint.empty;
        DoFs = [];
    end
    
    methods
        function obj = Divergence(Mach,NRoots)
            arguments
                Mach
                NRoots = 1
            end
            obj.Mach = Mach;
            obj.N_Roots= NRoots;
        end
        function ids = UpdateID(obj,ids)
                obj.Div_ID = ids.SID;
                obj.SPC_ID = ids.SID + 1;
                obj.Load_ID = ids.SID + 2;
                ids.SID = ids.SID + 3;
        end
        function str = config_string(obj)
            str = '';
        end
    end
end

