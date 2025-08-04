function fe = beam2fe(obj,baffOpts)
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
    error('beam stations must be in assending order with respect to Eta')
end

% get dicretised Eta positions
Etas = GetDiscreteEta(obj,baffOpts);
nodes = obj.GetPos(Etas);

% generate nodes
for i = 1:length(Etas)
    fe.Points(i) = ads.fe.Point(nodes(:,i),InputCoordSys=CS);
    fe.Forces(i) = ads.fe.Force([0;0;0],fe.Points(i));
end

% check if material is stiff
if obj.Stations.Mat(1).E == inf
    %generate rigid bars
    stations = obj.Stations.interpolate(Etas);
    for i = 1:length(stations)-1
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(i),fe.Points(i+1));
    end
else
    %generate material
    fe.Materials(end+1) = ads.fe.Material.FromBaffMat(obj.Stations.Mat(1));
    
    % generate Beam elements
    stations = obj.Stations.interpolate(Etas);
    for i = 1:stations.N-1
        % add a grid point to define y axis of beam
        dir = stations.StationDir(:,i);
        dir = dir./norm(dir);
        A_in = fe.Points(i).InputCoordSys.getAglobal;
        A_out = fe.Points(i).OutputCoordSys.getAglobal;
        dir = A_out'*A_in*dir;
        fe.Beams(i) = ads.fe.Beam.FromBaffStations(stations.GetIndex(i:i+1),fe.Points(i:i+1),fe.Materials(end));
        fe.Beams(i).yDir = dir;
    end
end

end
