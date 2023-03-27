function fe = constraint2fe(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
%TOFE Summary of this function goes here
%   Detailed explanation goes here
fe = ads.fe.Component();
fe.Name = obj.Name;
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
CS = fe.CoordSys(1);

for i = 1:length(obj)
    % generate nodes
    fe.Points(i) = ads.fe.Point([0;0;0], InputCoordSys=CS);
    % generate Constraint
    fe.Constraints(i) = ads.fe.Constraint(fe.Points(i),obj.ComponentNums);
end
end

