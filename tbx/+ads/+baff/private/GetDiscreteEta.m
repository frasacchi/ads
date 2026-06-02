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
    for i = 1:length(obj.Children)
        if norm(obj.Children(i).Offset) ~= 0
            cost = @(x)norm(obj.GetPos(obj.Children(i).Eta +x) - (obj.GetPos(obj.Children(i).Eta) + obj.Children(i).Offset));
            child_eta(i) = child_eta(i) + fminsearch(cost,0);
        end
    end
    tmpEtas = unique([etas,child_eta]);
    etas = tmpEtas(tmpEtas>=etas(1) & tmpEtas<=etas(end)); % ensure dont add points not on the beam
end
etas = round(etas,15);
end
