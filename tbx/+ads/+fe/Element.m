classdef Element < matlab.mixin.Heterogeneous & handle
    %COMPONENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Name = "";
        Tag = "";
    end
    
    methods
        function obj = Element(opts)
            
        end
        function Export(obj,fid)
            warning("Export Not Implemented for class %s",class(obj));
        end
        function ToFE(obj)
        end
        function plt_obj = drawElement(obj)
            plt_obj = [];
        end
        function ids = UpdateID(obj,ids)
        end
        function m = GetMass(obj)
            m = zeros(size(obj));
        end
    end
end

