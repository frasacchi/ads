classdef PlyDefinition
    properties
        Z0 double = -0.5;
        NSM double = nan;
        SB double = nan;
        FT string {mustBeMember(FT,["HILL","HOFF","TSAI","STRN","HFAIL","HTAPE","HFABR",""])} = "";
        TREF double = 0;
        GE double = 0;
        LAM string {mustBeMember(LAM,["SYM","MEM","BEND","SMEAR","SMCORE",""])} = "";

        % multiPly
        Layers(:,1) ads.fe.PlyLayer = ads.fe.PlyLayer;
    end
    methods
        function obj = PlyDefinition(Layers,Z0,NSM,SB,FT,TREF,GE,LAM)
            arguments
                Layers(:,1) ads.fe.PlyLayer = ads.fe.PlyLayer;
                Z0 double = -0.5;
                NSM double = NaN;
                SB double = NaN;
                FT string {mustBeMember(FT,["HILL","HOFF","TSAI","STRN","HFAIL","HTAPE","HFABR",""])} = "";
                TREF double = 0;
                GE double = 0;
                LAM string {mustBeMember(LAM,["SYM","MEM","BEND","SMEAR","SMCORE",""])} = "";
            end
            obj.Z0 = Z0;
            obj.NSM = NSM;
            obj.SB = SB;
            obj.FT = FT;
            obj.TREF = TREF;
            obj.GE = GE;
            obj.LAM = LAM;

            % multiPly
            obj.Layers = Layers;
        end

    end
    methods(Static)
        function obj = FromBaffStation(st)
            arguments
                st baff.station.ShellStation.Ply
            end

            Layers = ads.fe.PlyLayer.empty;
            for i = 1:length(st.Ti)
                Layers(i) = ads.fe.PlyLayer(st.MIDi(i),st.Ti(i),st.THETAi(i),st.SOUTi(i));
            end

            obj = ads.fe.PlyDefinition(Layers,st.Z0,st.NSM,st.SB,st.FT,st.TREF,st.GE,st.LAM);
        end
    end
end