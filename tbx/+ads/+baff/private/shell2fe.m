function [fe,Etas] = shell2fe(obj,baffOpts)
arguments
    obj
    baffOpts = ads.baff.BaffOpts();
end
%SHELL2FE baff shell to fe component
%   Detailed explanation goes here
fe = ads.fe.Component();
fe.Name = obj.Name;
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
CS = fe.CoordSys(1);

%check stations in correct order
if ~issorted([obj.Stations.Eta])
    error('shell stations must be in assending order with respect to Eta')
end

% get dicretised Eta positions
nodes = obj.Stations.Nodes;

% generate nodes
for i = 1:length(nodes)
    fe.Points(i) = ads.fe.Point(nodes(i,:),InputCoordSys=CS);
    % fe.Forces(i) = ads.fe.Force([0;0;0],fe.Points(i));
end

%generate material -- TODO - add MAT3 material definition
fe.Materials(end+1) = ads.fe.Material.FromBaffMat(obj.Stations.Mat(1)); 

% generate shell elements
shells = obj.Stations.Shell;
for i = 1:length(shells)
    fe.Shells(end+1) = ads.fe.Shell.FromBaffStations(shells(i),fe.Points(shells(i).G),fe.Materials(end),shells(i).Thickness);
end

Etas = obj.Stations.Eta;
nodesi = obj.GetPos(Etas);
nodesX= [fe.Points.X];

% generate attachement nodes
for i = 1:length(Etas)
    fe.Points(end+1) = ads.fe.Point(nodesi(:,i),InputCoordSys=CS,isAttachment=true);
    fe.Points(end).Tag = "AttachmentNode";
    idx = find(abs(nodesX(1,:) - nodesi(1,i)) < 1e-8);

    REFC=123456;%[1;2;3];
    Wti = 1.0/numel(idx);
    Ci = 123456;%[1;2;3];
    fe.RigidBodyElements(end+1) = ads.fe.RigidBodyElement(fe.Points(end),REFC,Wti,Ci,fe.Points(idx));
end

end
