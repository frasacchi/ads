classdef PlyLayer
    properties
        MID double = nan;
        T double = nan;
        THETA double = 0;
        SOUT string = "NO";
    end
    methods
        function obj = PlyLayer(MID,T,THETA,SOUT)
            arguments
                MID double = [];
                T double = 1;
                THETA double = 0;
                SOUT string = "NO";
            end
            obj.MID = MID;
            obj.T = T;
            obj.THETA = THETA;
            obj.SOUT = SOUT;
        end

        function plyLayer = ToMatran(obj)
            plyLayer = mni.printing.cards.PlyLayer(obj.MID, obj.T, obj.THETA, obj.SOUT);
        end

    end
end