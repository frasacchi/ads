classdef Element < matlab.mixin.Heterogeneous & handle
    %COMPONENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Name = "";
        isEtaable logical = false
        Tag = "";
    end
    
    methods
        function obj = Element(opts)
            
        end
        function Export(obj,fid)
            warning("Not Implemented")
        end
        function ToFE(obj)
        end
        function plt_obj = drawElement(obj)
            plt_obj = [];
        end
        function ids = UpdateID(obj,ids)
        end
    end
end

