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
if ~issorted(obj.Stations.Eta)
    error('Station Etas must be in ascending order')
end

% get dicretised Eta positions
Etas = GetDiscreteEta(obj,baffOpts);
nodes = zeros(3,length(Etas));
for i = 1:length(Etas)
    nodes(:,i) = obj.GetPos(Etas(i));
end

% generate nodes
for i = 1:length(Etas)
    fe.Points(i) = ads.fe.Point(nodes(:,i),InputCoordSys=CS);
end

% check if material is stiff
if obj.Stations.Mat(1).E == inf
    %generate rigid bars
    st = obj.Stations.interpolate(Etas);
    for i = 1:st.N-1
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(i),fe.Points(i+1));
    end
else
    %generate material
    fe.Materials(end+1) = ads.fe.Material.FromBaffMat(obj.Stations.Mat(1));
    
    % generate Beam elements
    st = obj.Stations.interpolate(Etas);
    for i = 1:st.N-1
        fe.Beams(i) = ads.fe.Beam.FromBaffStations(st.GetIndex(i:i+1),fe.Points(i:i+1),fe.Materials(end));
    end
end

end
