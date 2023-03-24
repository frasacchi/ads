classdef BaseCoordSys < ads.fe.AbsCoordSys
    %COORDSYS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Origin
        InputCoordSys = ads.fe.CoordSys.empty;
        A = eye(3);% rotation Matrix
        isBase = true;
        ID = 0;
    end
    methods
        function obj = BaseCoordSys()
            obj.Name = "Base";
        end
        function A = getAglobal(obj)
            A = obj.A;
        end
        function p = getPointGlobal(obj,p)
            p = repmat(obj.Origin,1,size(p,2)) + obj.A * p;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.CID;
                ids.CID = ids.CID + 1;
            end
        end
        function Export(obj,fid)
        end
    end
    methods(Static)
        function obj = get()
            persistent BaseCoord
            if isempty(BaseCoord)
                BaseCoord = ads.fe.BaseCoordSys();
            end
            obj = BaseCoord;
        end
    end
end

