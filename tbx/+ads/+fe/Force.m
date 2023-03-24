classdef Force < ads.fe.Element
    %MASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Point ads.fe.Point
        F (3,1) double;
        ID double = nan;
    end
    
    methods
        function obj = Force(F,Point)
            arguments
                F (3,1) double
                Point ads.fe.Point
            end
            %MASS Construct an instance of this class
            %   Detailed explanation goes here
            obj.F = F;
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
                mni.printing.bdf.writeComment(fid,"FORCE : Defines a Force at a point");
                mni.printing.bdf.writeColumnDelimiter(fid,"short");
                for i = 1:length(obj)
                    nF = norm(obj.F);
                    if nF == 0
                        N = [0 0 1];
                    else
                        N = obj.F/nF;
                    end
                    mni.printing.cards.FORCE(obj(i).ID,obj(i).Point.ID,nF,N,'CID',obj(i).Point.InputCoordSys.ID).writeToFile(fid);
                end
            end
        end
    end
end

