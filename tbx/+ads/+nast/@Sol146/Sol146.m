classdef Sol146 < handle
    %FLUTTERSIM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % generic aero parameters
        Name = 'Default SOL146: ';
        LoadFactor = 1;
        V = 0;
        rho = 0;
        Mach = 0;
        Alt = 0 ; % altitude in feet (for when gusts spec'ed to CS-25)
        AEQR = 1;
        ACSID = [];

        RefChord = 1;
        RefSpan = 1;
        RefArea = 1;
        RefDensity = 1.225;
        LModes = 0;

        % freqeuency & Structural Damping Info
        FreqRange = [0,50];
        NFreq = 500;
        ModalDampingPercentage = 0;
        GustFreq = [];

        DispIDs = [];
        ForceIDs = [];

        % gust data
        Gusts = ads.nast.gust.BaseSettings.empty;
        GustDuration = 5;
        GustTstep = 0.01;

        SDAMP_ID = 4;
        FREQ_ID = 5;
        TSTEP_ID = 6;
        EigR_ID = 7;
        DAREA_ID = 8;
        SPC_ID = 9;
        EPoint_ID = nan;

        SPCs = [];
        ReducedFreqs = [0.01,0.05,0.1,0.2,0.5,0.75,1,2,4];

        % CoM Info for Boundary Constraints
        isFree = false; % if is Free a Boundary condition will be applied to  the Centre of Mass
        CoM = ads.fe.Constraint.empty;
        DoFs = [];
    end
    
    methods
        function set_trim_steadyLevel(obj,V,rho,Mach,alt)
            arguments
                obj
                V
                rho
                Mach
                alt
            end
            obj.isFree = true;
            obj.V = V;
            obj.rho = rho;
            obj.Mach = Mach;
            obj.DoFs = 35;
            obj.Alt = alt;
        end
        function set_trim_locked(obj,V,rho,Mach)
            obj.V = V;
            obj.rho = rho;
            obj.Mach = Mach;
            obj.ANGLEA.Value = 0;
            obj.DoFs = [];
        end
        function obj = Sol146(CoM)
            obj.CoM = CoM;
        end
        function ids = UpdateID(obj,ids)
                obj.SDAMP_ID = ids.SID;
                obj.FREQ_ID = ids.SID + 1;
                obj.TSTEP_ID = ids.SID + 2;
                obj.EigR_ID = ids.SID + 3;
                obj.SPC_ID = ids.SID + 4;
                obj.DAREA_ID = ids.SID + 5;
                ids.SID = ids.SID + 7; % skip one for DAREA fun...

                obj.EPoint_ID = ids.ExtremeID;
                ids.ExtremeID = ids.ExtremeID - 1;
                for i = 1:length(obj.Gusts)
                    ids = obj.Gusts(i).UpdateID(ids);
                end
        end
        function str = config_string(obj)
            str = '';
        end
    end
end

