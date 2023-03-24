function [fe,AnchorPoints] = mass2fe(obj)
arguments
    obj baff.Mass
end
fe = point2fe(obj);

for i = 1:length(obj)
    % generate mass
    fe.Masses(i) = ads.fe.Mass(obj(i).mass,fe.Points(i));
    fe.Masses(i).InertiaTensor = obj(i).InertiaTensor;
end
AnchorPoints = fe.Points(1:end);
end

