classdef (Abstract) AbsCoordSys < ads.fe.Element
    %COORDSYS Summary of this class goes here
    %   Detailed explanation goes here
    properties (Abstract)
        Origin (3,1) double
        InputCoordSys ads.fe.AbsCoordSys;
        A (3,3) double;% rotation Matrix
        isBase;
        ID;
    end
    methods(Abstract)
        A = getAglobal(obj)
        p = getPointGlobal(obj,p)
    end
    methods
        function out = eq(obj,obj2)
            if isa(obj2,'ads.fe.AbsCoordSys')
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
    end
end

