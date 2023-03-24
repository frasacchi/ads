function [fe,AnchorPoints] = hinge2fe(obj)
arguments
    obj baff.Hinge
end
fe = ads.fe.Component();
fe.Name = obj.Name;

%% genrate coordinate systems
hv = obj.HingeVector./norm(obj.HingeVector);
A = ads.util.Rodrigues(hv,obj.Rotation);

%Output Coordinate System
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A*A);
%Hinge Coordinate system
x_dir = [1;0;0];
hinge_k = cross(x_dir,hv);
hinge_angle = atan2d(1,x_dir'*hv);
A = ads.util.Rodrigues(hinge_k,hinge_angle);
fe.CoordSys(2) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A*A);

% generate two coincedent nodes
for i = 1:2
    fe.Points(i) = ads.fe.Point(zeros(3,1),InputCoordSys=fe.CoordSys(2),OutputCoordSys=fe.CoordSys(2));
end
fe.Points(1).JointType = ads.fe.JointType.Rigid;
AnchorPoints = fe.Points(end);

%generate hinge
h = ads.fe.Hinge(fe.Points(1:end),fe.CoordSys(2),obj.K,obj.C,isLocked=obj.isLocked);
fe.Hinges(1) = h;
end

