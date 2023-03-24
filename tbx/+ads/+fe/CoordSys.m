classdef CoordSys < ads.fe.AbsCoordSys
    %COORDSYS Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Origin
        InputCoordSys = ads.fe.BaseCoordSys.get;
        A = eye(3);% rotation Matrix
        isBase = false;
        ID = 1;
    end

    methods
        function obj = CoordSys(opts)
            arguments
                opts.Origin = [0;0;0];
                opts.A = eye(3);
                opts.InputCoord = ads.fe.BaseCoordSys.get;
                opts.ID = randi(1e9-1,1)+1;
            end
            obj.Origin = opts.Origin;
            obj.A = opts.A;
            obj.InputCoordSys = opts.InputCoord;
            obj.ID = opts.ID;
        end
        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).ID = ids.CID;
                ids.CID = ids.CID + 1;
            end
        end
        function A = getAglobal(obj)
            A = obj.A;
            A = obj.InputCoordSys.getAglobal*A;
        end
        function p = getPointGlobal(obj,p)
            p = repmat(obj.Origin,1,size(p,2)) + obj.A * p;
            p = obj.InputCoordSys.getPointGlobal(p);
        end
        function p = getOriginGlobal(obj)
            p = obj.InputCoordSys.getPointGlobal(obj.Origin);
        end
        function vPrime = getPointGlobal2Local(obj,p)
            o = obj.getPointGlobal([0;0;0]);
            % get vector from origin to point in global coordinate system
            v = p-o;
            %convert vector to local coordinate system
            vPrime = obj.getAglobal()'*v;
        end
        function out = eq(obj,obj2)
            if isa(obj2,'ads.fe.CoordSys')
                out = obj2.ID == obj.ID;
                if ~out
                    return
                elseif obj2.Origin ~= obj.Origin
                    error('CoordSys have same ID but different Origin')
                elseif obj2.InputCoordSys ~= obj.InputCoordSys
                    error('CoordSys have same ID but different InputCoordSys')
                elseif obj2.A ~= obj.A
                    error('CoordSys have same ID but different A')
                end
            else
                out = false;
            end
        end
        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"CORD2R: Defines a rectangular coordinate system using the coordinates of three points.");
                mni.printing.bdf.writeColumnDelimiter(fid,"long")
                for i = 1:length(obj)
                    if ~obj(i).isBase
                        Ai = obj(i).Origin;
                        Bi = obj(i).Origin + obj(i).A*[0;0;1];
                        Ci = obj(i).Origin + obj(i).A*[1;0;0];
                        tmpCard = mni.printing.cards.CORD2R(obj(i).ID,Ai,Bi,Ci,"RID",obj(i).InputCoordSys.ID);
                        tmpCard.LongFormat = true;
                        tmpCard.writeToFile(fid);
                    end
                end
            end
        end
    end
    methods(Static)
        function obj = Base()
            persistent BaseCoord
            if isempty(BaseCoord)
                BaseCoord = ads.fe.CoordSys(ID=0);
                BaseCoord.isBase = true;
            end
            obj = BaseCoord;
        end
    end
end

