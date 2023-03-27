function [etas] = GetDiscreteEta(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
%GETDISCRETEETA Summary of this function goes here
%   Detailed explanation goes here
etas = [obj.Stations.Eta];
% add eta from all children
if baffOpts.SplitBeamsAtChildren
    child_eta = [obj.Children.Eta];
    etas = unique([etas,child_eta]);
    etas = etas(etas>=0 & etas<=1);
end
% ensure only make beam elements between eta 0 and 1 (children can have greater etas!)
if etas(1)~=0 || etas(end)~=1
    error('eta must start and end at 0 and 1')
end
end
