classdef OutRequest
    %OUTREQUEST Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Type string
        IDs double = []
        Args string = ["SORT1","REAL"]
        WriteToF06 = true;
    end

    methods
        function obj = OutRequest(Type,IDs,Args)
            arguments
                Type
                IDs = inf
                Args = ["SORT1","REAL"]
            end
            obj.Type = Type;
            obj.IDs = IDs;
            obj.Args = Args;
        end

        function WriteToFile(obj,fid)
            for i = 1:length(obj)
                tOut = obj(i);
                if ~isscalar(tOut.IDs) && (any(isnan(tOut.IDs)) || any(isinf(tOut.IDs)))
                    error('If specifying multiple output IDs, cannot include NaN or Inf values');
                end
                if isempty(tOut.IDs) || isinf(tOut.IDs)
                    IDset = 'ALL';
                elseif any(isnan(tOut.IDs))
                    IDset = 'NONE';
                else
                    mni.printing.cases.SET(i,tOut.IDs).writeToFile(fid);
                    IDset = num2str(i);
                end
    
                if ~tOut.WriteToF06
                    tArgs = [tOut.Args,"PLOT"];
                else
                    tArgs = tOut.Args;
                end
    
                outRqstStr = [char(tOut.Type),'(',char(strjoin(unique(upper(tArgs)),',')),')'];
                fprintf(fid,[outRqstStr, ' = ', IDset,'\n']);
            end
        end
    end
end