function fe = hinge2fe(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
fe = ads.fe.Component();
fe.Name = obj.Name;

%% genrate coordinate systems
hv = obj.HingeVector./norm(obj.HingeVector);
A = dcrg.geom.Rodrigues(hv,deg2rad(obj.Rotation));

%Output Coordinate System
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A*A);
%Hinge Coordinate system
x_dir = [1;0;0];
hinge_k = cross(x_dir,hv);
if norm(hinge_k) == 0
    A = eye(3);
else
    nhinge_k = norm(hinge_k);
    hinge_angle = atan2(nhinge_k,x_dir'*hv);
    A = dcrg.geom.Rodrigues(hinge_k./nhinge_k,hinge_angle);
end
fe.CoordSys(2) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A*A);

% generate two coincedent nodes
for i = 1:2
    fe.Points(i) = ads.fe.Point(zeros(3,1),InputCoordSys=fe.CoordSys(2),OutputCoordSys=fe.CoordSys(2));
end
fe.Points(1).isAttachmentPoint = false;
fe.Points(2).isAnchorPoint = false;

%generate hinge
fe.Hinges(1) = ads.fe.Hinge(fe.Points(1:end),fe.CoordSys(2),obj.K,obj.C,isLocked=obj.isLocked);
end

