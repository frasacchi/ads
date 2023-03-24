function [etas] = GetDiscreteEta(obj,NumElements)
arguments
    obj baff.Beam
    NumElements double = 10;
end
%GETDISCRETEETA Summary of this function goes here
%   Detailed explanation goes here
st_etas = [obj.Stations.Eta];
% add eta from all children
child_eta = [obj.Children.Eta];
st_etas = unique([st_etas,child_eta]);
st_etas = st_etas(st_etas>=0 & st_etas<=1);
%split each section to get required number of total elements
if st_etas(1)~=0 || st_etas(end)~=1
    error('eta must start and end at 0 and 1')
end
if NumElements <= length(st_etas)-1
    etas = st_etas;
else
    delta = st_etas(2:end)-st_etas(1:end-1);
    Ns = round(delta*(NumElements-length(st_etas)));
    etas = 0;
    for i = 1:length(Ns)
        tmp_eta = linspace(st_etas(i),st_etas(i+1),2+Ns(i));
        etas = [etas,tmp_eta(2:end)];
    end
end
end
