classdef JointType
    %JOINTS Summary of this class goes here
    %   Detailed explanation goes here
    properties
        Radius = 1; %TODO Interp should be an rbe3 for all points within this radius
    end
    
    enumeration
        Anchor,Interp,None
    end
end

