classdef SubCase
    %SUBCASE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        SubTitle string = '';
        SPC double = nan;
        Method double = nan;
    end
    
    methods
        function obj = SubCase(opts)
            arguments
                opts.SubTitle = '';
                opts.SPC = [];
                opts.Method = [];
            end
            obj.SubTitle = opts.SubTitle;
            obj.SPC = opts.SPC;
            obj.Method = opts.Method;
        end
        
        function WriteToFile(obj,fid,id)
            fprintf(fid,'SUBCASE %.0f\n',id);
            if ~isempty(obj.SubTitle)
                fprintf(fid,'  SUBTITLE=%s\n',obj.SubTitle);
            end
            if ~isnan(obj.SPC)
                fprintf(fid,'  SPC=%.0f\n',obj.SPC);
            end
            if ~isnan(obj.Method)
                fprintf(fid,'  METHOD=%.0f\n',obj.Method);
            end
        end
    end
end

