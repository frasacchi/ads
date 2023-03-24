function A = Rodrigues(v,angle)
%RODRIGUES Reurns the rotation matix assiated with the vector omega
%   omega is a vector whos direction refines the axis of rotation and who
%   magnitude defines the magnitude of rotation (in radians)
if angle == 0
    A = eye(3);
else
    n = v./norm(v);
    A = eye(3)+ Wedge(n)*sind(angle) + Wedge(n)*Wedge(n)*(1-cosd(angle));
end
end


function V  = Wedge(v)
V = zeros(3);
V(1,2) = -v(3);
V(2,1) = v(3);
V(3,1) = -v(2);
V(1,3) = v(2);
V(2,3) = -v(1);
V(3,2) = v(1);
end
