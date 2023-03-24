function fe = baff2fe(obj)
arguments
    obj baff.Model
end
%BAFF2FE Summary of this function goes here
%   Detailed explanation goes here
fe = ads.fe.Component();
fe.Name = obj.Name;
for i = 1:length(obj.Orphans)
    fe.Components(i) = ads.baff.element2fe(obj.Orphans(i));
end
fe.Flatten();
end

