classdef TrimParameter
    %TrimParameter Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Name;
        Value;
        Type;
        Link = [];
    end
    
    methods
        function obj = TrimParameter(Name,Value,Type)
            arguments
                Name string
                Value double
                Type string {mustBeMember(Type,["Rigid Body","Control Surface"])}
            end
            obj.Name = Name;
            obj.Value = Value;
            obj.Type = Type;
        end
    end
end

