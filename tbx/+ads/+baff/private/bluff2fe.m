function fe = bluff2fe(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
%BEAM2FE baff beam to fe component
%   Detailed explanation goes here
fe = ads.fe.Component();
fe.Name = obj.Name;
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
CS = fe.CoordSys(1);

%check stations in correct order
if ~issorted([obj.Stations.Eta])
    error('beam stations must be in assending order with respect to eta')
end

%check stations in correct order
[~,st_idx] = sort([obj.Stations.Eta]);
obj.Stations = obj.Stations(st_idx);

% get dicretised Eta positions
Etas = GetDiscreteEta(obj);
nodes = zeros(3,length(Etas));
for i = 1:length(Etas)
    nodes(:,i) = obj.GetPos(Etas(i));
end

% generate nodes
for i = 1:length(Etas)
    fe.Points(i) = ads.fe.Point(nodes(:,i),InputCoordSys=CS);
end

% check if material is stiff
if obj.Stations(1).Mat.E == inf
    %generate rigid bars
    stations = obj.Stations.interpolate(Etas);
    for i = 1:length(stations)-1
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(i),fe.Points(i+1));
    end
else
    %generate material
    fe.Materials(end+1) = ads.fe.Material.FromBaffMat(obj.Stations(1).Mat);
    
    % generate Beam elements
    stations = obj.Stations.interpolate(Etas);
    for i = 1:length(stations)-1
        fe.Beams(i) = ads.fe.Beam.FromBaffStations(stations(i:i+1),fe.Points(i:i+1),fe.Materials(end));
    end
end

end
