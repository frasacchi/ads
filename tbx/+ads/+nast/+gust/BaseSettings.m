classdef (Abstract) BaseSettings < handle & matlab.mixin.Heterogeneous
    %BASEGUSTSETTINGS Summary of this class goes here
    %   Detailed explanation goes here
    
    methods(Abstract)
        ids = UpdateID(obj,ids)
        write_subcase(obj,fid,idx)
        obj = set_params(obj,V,opts)
        write_bdf(obj,fid,V,idx,opts)
    end
    methods (Static, Sealed, Access = protected)
        function default_object = getDefaultScalarElement
            default_object = ads.nast.gust.OneMC(nan,nan,nan);
        end
    end
    
end

