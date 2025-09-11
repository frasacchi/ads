classdef Moment < ads.fe.Element
    %MASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Point ads.fe.Point
        M (3,1) double;
        ID double = nan;
    end
    
    methods
        function obj = Moment(M,Point)
            arguments
                M (3,1) double
                Point ads.fe.Point
            end
            obj.M = M;
            obj.Point = Point;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.SID;
                ids.SID = ids.SID + 1;
            end
        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"MOMENT : Defines a monment at a point");
                mni.printing.bdf.writeColumnDelimiter(fid,"short");
                for i = 1:length(obj)
                    nM = norm(obj(i).M);
                    if nM == 0
                        N = [0 0 1];
                    else
                        N = obj(i).M/nM;
                    end
                    mni.printing.cards.MOMENT(obj(i).ID,obj(i).Point.ID,nM,N,'CID',obj(i).Point.InputCoordSys.ID).writeToFile(fid);
                end
            end
        end
    end
end

