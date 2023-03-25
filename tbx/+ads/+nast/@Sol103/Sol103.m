classdef Sol103 < handle
    %FLUTTERSIM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % generic aero parameters
        Name = 'SOL103';

        % freqeuency & Structural Damping Info
        FreqRange = [0.01,50];
        NFreq = 500;
        LModes = 20;
        ModalDampingPercentage = 0;

        EigR_ID = 1;
        SPC_ID = 2;
        SPCs = [];

        %CoM and constraint Paramters
        g = 9.81;
        Grav_Vector = [0;0;1];
        CoM_gp = 1;
        CoM_GID = 99999999;
        CoM_Cp = [];
        CoM = [0;0;0];
    end
    
    methods
        function ids = UpdateID(obj,ids)
                obj.EigR_ID = ids.SID;
                obj.SPC_ID = ids.SID + 1;
                ids.SID = ids.SID + 2;
        end
        function str = config_string(obj)
            str = '';
        end
    end
end

