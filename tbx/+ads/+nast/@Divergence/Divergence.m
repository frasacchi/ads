classdef Divergence < ads.nast.BaseSol
    %DIVERGENCE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % generic aero parameters
        Name = 'sol144_div';
        Mach = 0;

        N_Roots = 1;
        eig_meth char = 'CLAN';

        Div_ID = 1
        SPC_ID = 2;
        Load_ID = 4;
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
    end
end

