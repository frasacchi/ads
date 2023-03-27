function fe = baff2fe(obj,baffOpts)
arguments
    obj baff.Model
    baffOpts = ads.baff.BaffOpts();
end
%BAFF2FE Summary of this function goes here
%   Detailed explanation goes here
fe = ads.fe.Component();
fe.Name = obj.Name;
for i = 1:length(obj.Orphans)
    fe.Components(i) = ads.baff.element2fe(obj.Orphans(i),baffOpts);
end
fe.Flatten();
end

