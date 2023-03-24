function [fe,AnchorPoints] = bluff2fe(obj,opts)
arguments
    obj baff.BluffBody
    opts.NumElements = 10;
end
%BEAM2FE baff beam to fe component
%   Detailed explanation goes here
fe = ads.fe.Component();
fe.Name = obj.Name;
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
CS = fe.CoordSys(1);

%check stations in correct order
if ~issorted([obj.Stations.eta])
    error('beam stations must be in assending order with respect to eta')
end

%check stations in correct order
[~,st_idx] = sort([obj.Stations.eta]);
obj.Stations = obj.Stations(st_idx);

% get dicretised Eta positions
dir = obj.xDir./norm(obj.xDir);
b_end = dir*obj.Length;
etas = GetDiscreteEta(obj,opts.NumElements);

% generate nodes
nodes = repmat(b_end,1,length(etas)).*repmat(etas,3,1);
for i = 1:length(nodes)
    fe.Points(i) = ads.fe.Point(nodes(:,i),InputCoordSys=CS);
    if i==1
        fe.Points(i).JointType = ads.fe.JointType.Rigid;
    end
end
AnchorPoints = fe.Points(1:end);

% check if material is stiff
if obj.Stations(1).Mat.E == inf
    %generate rigid bars
    stations = obj.Stations.interpolate(etas);
    for i = 1:length(stations)-1
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(i),fe.Points(i+1));
    end
else
    %generate material
    fe.Materials(end+1) = ads.fe.Material.FromModelMaterial(obj.Stations(1).Mat);
    
    % generate Beam elements
    stations = obj.Stations.interpolate(etas);
    for i = 1:length(stations)-1
        fe.Beams(i) = ads.fe.Beam.FromModelStations(stations(i:i+1),fe.Points(i:i+1),fe.Materials(end));
    end
end

end
